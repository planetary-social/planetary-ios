// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"context"
	"encoding/json"
	"fmt"
	"io"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/muxrpc/v2/typemux"
	kitlog "go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

// TunnelPlugin returns a muxrpc plugin that is able to handle incoming tunnel.connect requests
func (n *Node) TunnelPlugin() ssb.Plugin {
	tunnelLogger := kitlog.With(n.log, "unit", "tunnel")
	rootHdlr := typemux.New(tunnelLogger)

	rootHdlr.RegisterAsync(muxrpc.Method{"tunnel", "isRoom"}, isRoomhandler{})
	rootHdlr.RegisterDuplex(muxrpc.Method{"tunnel", "connect"}, connectHandler{
		network: n,
		logger:  tunnelLogger,
	})

	return plugin{
		h: handleNewConnection{
			Handler: &rootHdlr,
			logger:  tunnelLogger,
		},
	}
}

// muxrpc shim
type plugin struct{ h muxrpc.Handler }

func (plugin) Name() string              { return "tunnel" }
func (plugin) Method() muxrpc.Method     { return muxrpc.Method{"tunnel"} }
func (p plugin) Handler() muxrpc.Handler { return p.h }

// tunnel.isRoom should return true for a tunnel server and false for clients
type isRoomhandler struct{}

func (h isRoomhandler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	return false, nil
}

type connectHandler struct {
	network *Node

	logger kitlog.Logger
}

func (h connectHandler) HandleDuplex(ctx context.Context, req *muxrpc.Request, peerSrc *muxrpc.ByteSource, peerSnk *muxrpc.ByteSink) error {
	portal, err := ssb.GetFeedRefFromAddr(req.Endpoint().Remote())
	if err != nil {
		return err
	}

	portalLogger := kitlog.With(h.logger, "portal", portal.ShortSigil())
	level.Info(portalLogger).Log("event", "incomming tunnel.connect", "args", string(req.RawArgs))

	// wrap muxrpc duplex into a net.Conn like thing
	var tc tunnelConn
	tc.Reader = muxrpc.NewSourceReader(peerSrc)
	tc.WriteCloser = muxrpc.NewSinkWriter(peerSnk)
	tc.local = h.network.opts.ListenAddr
	tc.remote = tunnelHost{
		Host: portal,
	}
	ctx, tc.cancel = context.WithCancel(ctx)

	authWrapper := h.network.secretServer.ConnWrapper()

	conn, err := authWrapper(tc)
	if err != nil {
		level.Warn(portalLogger).Log("event", "tunnel.connect failed to authenticate", "err", err)
		tc.cancel()
		return err
	}

	origin, err := ssb.GetFeedRefFromAddr(conn.RemoteAddr())
	if err != nil {
		level.Warn(portalLogger).Log("event", "failed to get feed for remote tunnel", "err", err)
		tc.cancel()
		return err
	}

	level.Info(portalLogger).Log("event", "tunnel.connect established", "origin", origin.ShortSigil())

	// start serving the connection
	go h.network.handleConnection(ctx, conn, true)

	return nil
}

// handleNewConnection wrapps a muxrpc.Handler to do some stuff with new connections
type handleNewConnection struct {
	muxrpc.Handler

	logger kitlog.Logger
}

// HandleConnect checks if a new connection is a room (via tunnel.isRoom) and if it is,
// it opens and outputs tunnel.endpoints updates to the logging system.
func (newConn handleNewConnection) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
	remote, err := ssb.GetFeedRefFromAddr(edp.Remote())
	if err != nil {
		return
	}

	peerLogger := kitlog.With(newConn.logger, "peer", remote.ShortSigil())

	// check tunnel.isRoom
	var meta interface{}
	err = edp.Async(ctx, &meta, muxrpc.TypeJSON, muxrpc.Method{"room", "metadata"})
	yes, isBool := meta.(bool)
	if err != nil || (isBool && yes == false) {
		return
	}

	level.Info(peerLogger).Log("event", "room connection", "meta", fmt.Sprintf("%+v", meta))

	// open member updates stream
	src, err := edp.Source(ctx, muxrpc.TypeJSON, muxrpc.Method{"room", "attendants"})
	if err != nil {
		level.Warn(peerLogger).Log("event", "failed to open attendants stream", "err", err)
		return
	}

	// fist object: initial state
	if !src.Next(ctx) {
		level.Warn(peerLogger).Log("event", "failed to receive first message", "err", src.Err())
		return
	}

	stateBytes, err := src.Bytes()
	if err != nil {
		level.Warn(peerLogger).Log("event", "failed to receive initial state bytes", "err", err, "src", src.Err())
		return
	}

	var initState struct {
		Type string
		IDs  []refs.FeedRef
	}
	err = json.Unmarshal(stateBytes, &initState)
	if err != nil {
		level.Warn(peerLogger).Log("event", "failed to decode initial state", "err", err)
		return
	}
	for i, f := range initState.IDs {
		level.Info(peerLogger).Log("i", i, "attendant", f.String())
	}

	// stream further updates
	for src.Next(ctx) {

		var stateChange struct {
			Type string       `json:"type"`
			ID   refs.FeedRef `json:"id"`
		}

		err := src.Reader(func(rd io.Reader) error {
			return json.NewDecoder(rd).Decode(&stateChange)
		})
		if err != nil {
			level.Warn(peerLogger).Log("event", "failed to read from endpoints", "err", err)
			break
		}
		level.Info(peerLogger).Log(stateChange.Type, stateChange.ID.ShortSigil())
	}

	if err := src.Err(); err != nil {
		level.Error(peerLogger).Log("event", "endpoints stream closed", "err", err)
	}
}
