// SPDX-License-Identifier: MIT

// Package replicate roughly translates to npm:ssb-replicate and only selects which feeds to block and fetch.
//
// TODO: move ctrl.replicate and ctrl.block here.
package replicate

import (
	"context"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc/v2"

	"go.cryptoscope.co/ssb"
)

type replicatePlug struct {
	h muxrpc.Handler
}

// TODO: add replicate, block, changes
func NewPlug(users multilog.MultiLog) ssb.Plugin {
	plug := &replicatePlug{}
	plug.h = replicateHandler{
		users: users,
	}
	return plug
}

func (lt replicatePlug) Name() string { return "replicate" }

func (replicatePlug) Method() muxrpc.Method {
	return muxrpc.Method{"replicate"}
}
func (lt replicatePlug) Handler() muxrpc.Handler {
	return lt.h
}

type replicateHandler struct {
	users multilog.MultiLog
}

func (replicateHandler) Handled(m muxrpc.Method) bool { return m.String() == "replicate.upto" }

func (g replicateHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (g replicateHandler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	src, err := ssb.FeedsWithSequnce(g.users)
	if err != nil {
		req.CloseWithError(fmt.Errorf("replicate: did not get feed source: %w", err))
		return
	}

	err = luigi.Pump(ctx, req.Stream, src)
	if err != nil {
		req.CloseWithError(fmt.Errorf("replicate: failed to pump feed statuses: %w", err))
		return

	}

	req.Stream.Close()
}
