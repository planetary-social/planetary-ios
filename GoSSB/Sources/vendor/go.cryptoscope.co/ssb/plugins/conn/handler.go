// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package conn offers muxrpc helpers to connect to remote peers.
//
package conn

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/muxrpc/v2/typemux"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	multiserver "go.mindeco.de/ssb-multiserver"
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/ssb"
)

type handler struct {
	node ssb.Network
	repl ssb.Replicator

	info logging.Interface
}

func New(i logging.Interface, n ssb.Network, r ssb.Replicator) muxrpc.Handler {
	h := &handler{
		info: i,
		node: n,
		repl: r,
	}

	mux := typemux.New(i)

	mux.RegisterAsync(muxrpc.Method{"conn", "dialViaRoom"}, typemux.AsyncFunc(h.dialViaRoom))

	mux.RegisterAsync(muxrpc.Method{"conn", "connect"}, typemux.AsyncFunc(h.connect))
	mux.RegisterAsync(muxrpc.Method{"conn", "disconnect"}, typemux.AsyncFunc(h.disconnect))

	mux.RegisterAsync(muxrpc.Method{"conn", "replicate"}, unmarshalActionMap(h.replicate))
	mux.RegisterAsync(muxrpc.Method{"conn", "block"}, unmarshalActionMap(h.block))
	return &mux
}

type actionMap map[refs.FeedRef]bool

type actionFn func(context.Context, actionMap) error

// muxrpc always passes an array of option arguments
// this hack unboxes [{ feed:bool, feed2:bool, ...}] and [feed1,feed2,...] (all implicit true) into an actionMap and passes it to next
func unmarshalActionMap(next actionFn) typemux.AsyncFunc {
	return typemux.AsyncFunc(func(ctx context.Context, r *muxrpc.Request) (interface{}, error) {
		var refMap actionMap
		var args []map[string]bool
		err := json.Unmarshal(r.RawArgs, &args)
		if err != nil {
			// failed, trying array of feed strings
			var ref []refs.FeedRef
			err = json.Unmarshal(r.RawArgs, &ref)
			if err != nil {
				return nil, fmt.Errorf("action unmarshal: bad arguments: %w", err)
			}
			refMap = make(actionMap, len(ref))
			for _, v := range ref {
				refMap[v] = true
			}
		} else { // assuming array with one object
			if len(args) != 1 {
				return nil, fmt.Errorf("action unrmashal: expect one object")
			}
			refMap = make(actionMap, len(args[0]))
			for r, a := range args[0] {
				ref, err := refs.ParseFeedRef(r)
				if err != nil {
					return nil, err
				}
				refMap[ref] = a
			}
		}
		if err := next(ctx, refMap); err != nil {
			return nil, err
		}
		return struct {
			Action string
			Feeds  interface{}
		}{"updated", len(refMap)}, nil
	})
}

func (h *handler) replicate(ctx context.Context, m actionMap) error {
	for ref, do := range m {
		if do {
			h.repl.Replicate(ref)
		} else {
			h.repl.DontReplicate(ref)
		}
	}
	return nil
}

func (h *handler) block(ctx context.Context, m actionMap) error {
	for ref, do := range m {
		if do {
			h.repl.Block(ref)
		} else {
			h.repl.Unblock(ref)
		}
	}
	return nil
}

type reply struct {
	Result string `json:"result"`
}

func (h *handler) disconnect(ctx context.Context, r *muxrpc.Request) (interface{}, error) {

	var args []refs.FeedRef
	err := json.Unmarshal(r.RawArgs, &args)
	if err != nil {

		var rawArray []string
		err := json.Unmarshal(r.RawArgs, &rawArray)
		if err != nil {
			return nil, fmt.Errorf("bad argument: %w", err)
		}

		for i, a := range rawArray {
			na, err := multiserver.ParseNetAddress([]byte(a))
			if err != nil {
				return nil, fmt.Errorf("bad argument no %d (%q): %w", i, string(a), err)
			}
			args = append(args, na.Ref)
		}
	}

	if len(args) == 0 {
		ct := h.node.GetConnTracker()
		ct.CloseAll()
	} else {
		for _, ref := range args {
			if edp, has := h.node.GetEndpointFor(ref); has {
				edp.Terminate()
			}
		}
	}

	return reply{"disconencted"}, nil
}

func (h *handler) connect(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []string
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return nil, fmt.Errorf("ctrl.connect call: invalid arguments: %w", err)
	}
	if len(args) != 1 {
		h.info.Log("error", "usage", "args", req.Args, "method", req.Method)
		return nil, errors.New("usage: ctrl.connect host:port:key")
	}
	dest := args[0]

	msaddr, err := multiserver.ParseNetAddress([]byte(dest))
	if err != nil {
		return nil, fmt.Errorf("ctrl.connect call: failed to parse input %q: %w", dest, err)
	}

	wrappedAddr := netwrap.WrapAddr(&msaddr.Addr, secretstream.Addr{PubKey: msaddr.Ref.PubKey()})
	level.Info(h.info).Log("event", "connecting to peer", "remote", msaddr.Ref.ShortSigil())
	// TODO: add context to tracker to cancel connections
	err = h.node.Connect(context.Background(), wrappedAddr)
	if err != nil {
		return nil, fmt.Errorf("ctrl.connect call: error connecting to %q: %w", msaddr.Addr, err)
	}
	return reply{"conencted"}, nil
}

func (h *handler) dialViaRoom(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []string
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return nil, fmt.Errorf("ctrl.dialViaRoom: invalid arguments: %w", err)
	}
	if len(args) != 1 {
		h.info.Log("error", "usage", "args", req.Args, "method", req.Method)
		return nil, errors.New("usage: ctrl.dialViaRoom tunnel:@roomID.ed25519:@target.ed25519~target")
	}
	dest := args[0]

	tunAddr, err := multiserver.ParseTunnelAddress(dest)
	if err != nil {
		return nil, fmt.Errorf("ctrl.dialViaRoom: failed to parse input %q: %w", dest, err)
	}

	err = h.node.DialViaRoom(tunAddr.Intermediary, tunAddr.Target)
	if err != nil {
		return nil, err
	}

	return reply{"connected"}, nil
}
