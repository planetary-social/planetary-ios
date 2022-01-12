// SPDX-License-Identifier: MIT

package control

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	"go.cryptoscope.co/ssb/internal/muxmux"
	multiserver "go.mindeco.de/ssb-multiserver"

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

	mux := muxmux.New(i)

	mux.RegisterAsync(muxrpc.Method{"ctrl", "connect"}, muxmux.AsyncFunc(h.connect))
	mux.RegisterAsync(muxrpc.Method{"ctrl", "disconnect"}, muxmux.AsyncFunc(h.disconnect))

	mux.RegisterAsync(muxrpc.Method{"ctrl", "replicate"}, unmarshalActionMap(h.replicate))
	mux.RegisterAsync(muxrpc.Method{"ctrl", "block"}, unmarshalActionMap(h.block))
	return &mux
}

type actionMap map[*ssb.FeedRef]bool

type actionFn func(context.Context, actionMap) error

// muxrpc always passes an array of option arguments
// this hack unboxes [{ feed:bool, feed2:bool, ...}] and [feed1,feed2,...] (all implicit true) into an actionMap and passes it to next
func unmarshalActionMap(next actionFn) muxmux.AsyncFunc {
	return muxmux.AsyncFunc(func(ctx context.Context, r *muxrpc.Request) (interface{}, error) {
		var refs actionMap
		var args []map[string]bool
		err := json.Unmarshal(r.RawArgs, &args)
		if err != nil {
			// failed, trying array of feed strings
			var ref []*ssb.FeedRef
			err = json.Unmarshal(r.RawArgs, &ref)
			if err != nil {
				return nil, fmt.Errorf("action unmarshal: bad arguments: %w", err)
			}
			refs = make(actionMap, len(ref))
			for _, v := range ref {
				refs[v] = true
			}
		} else { // assuming array with one object
			if len(args) != 1 {
				return nil, fmt.Errorf("action unrmashal: expect one object")
			}
			refs = make(actionMap, len(args[0]))
			for r, a := range args[0] {
				ref, err := ssb.ParseFeedRef(r)
				if err != nil {
					return nil, err
				}
				refs[ref] = a
			}
		}
		if err := next(ctx, refs); err != nil {
			return nil, err
		}
		return fmt.Sprintf("updated %d feeds", len(refs)), nil
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

func (h *handler) disconnect(ctx context.Context, r *muxrpc.Request) (interface{}, error) {
	h.node.GetConnTracker().CloseAll()
	return "disconencted", nil
}

func (h *handler) connect(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	if len(req.Args()) != 1 {
		h.info.Log("error", "usage", "args", req.Args, "method", req.Method)
		return nil, errors.New("usage: ctrl.connect host:port:key")
	}
	dest, ok := req.Args()[0].(string)
	if !ok {
		return nil, errors.Errorf("ctrl.connect call: expected argument to be string, got %T", req.Args()[0])
	}
	msaddr, err := multiserver.ParseNetAddress([]byte(dest))
	if err != nil {
		return nil, errors.Wrapf(err, "ctrl.connect call: failed to parse input: %s", dest)
	}

	wrappedAddr := netwrap.WrapAddr(&msaddr.Addr, secretstream.Addr{PubKey: msaddr.Ref.PubKey()})
	level.Info(h.info).Log("event", "doing gossip.connect", "remote", msaddr.Ref.ShortRef())
	// TODO: add context to tracker to cancel connections
	err = h.node.Connect(context.Background(), wrappedAddr)
	return nil, errors.Wrapf(err, "ctrl.connect call: error connecting to %q", msaddr.Addr)
}
