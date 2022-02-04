// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"context"
	"errors"

	"go.cryptoscope.co/muxrpc/v2"
	kitlog "go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

type connectArg struct {
	Portal refs.FeedRef `json:"portal"`
	Target refs.FeedRef `json:"target"`
}

func (n *Node) DialViaRoom(portal, target refs.FeedRef) error {
	portalLogger := kitlog.With(n.log, "portal", portal.ShortSigil())

	edp, has := n.GetEndpointFor(portal)
	if !has {
		return errors.New("ssb/network: room offline")
	}

	var arg connectArg
	arg.Portal = portal
	arg.Target = target

	ctx := context.TODO() // TODO: get serveCtx from sbot

	ctx, cancel := context.WithCancel(ctx)
	r, w, err := edp.Duplex(ctx, muxrpc.TypeBinary, muxrpc.Method{"tunnel", "connect"}, arg)
	if err != nil {
		cancel()
		return err
	}

	var tc tunnelConn
	tc.Reader = muxrpc.NewSourceReader(r)
	tc.WriteCloser = muxrpc.NewSinkWriter(w)

	tc.cancel = cancel

	tc.local = n.opts.ListenAddr
	tc.remote = tunnelHost{
		Host: portal,
	}

	authWrapper := n.secretClient.ConnWrapper(target.PubKey())

	conn, err := authWrapper(tc)
	if err != nil {
		level.Warn(portalLogger).Log("event", "tunnel.connect failed to authenticate", "err", err)
		cancel()
		return err
	}

	origin, err := ssb.GetFeedRefFromAddr(conn.RemoteAddr())
	if err != nil {
		level.Warn(portalLogger).Log("event", "failed to get feed for remote tunnel", "err", err)
		cancel()
		return err
	}

	level.Info(portalLogger).Log("event", "tunnel.connect established", "origin", origin.ShortSigil())

	// start serving the connection
	go n.handleConnection(ctx, conn, false)

	return nil
}
