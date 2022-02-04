// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package whoami

import (
	"context"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/ssb"
)

var (
	_      ssb.Plugin = plugin{} // compile-time type check
	method            = muxrpc.Method{"whoami"}
)

func checkAndLog(log logging.Interface, err error) {
	if err != nil {
		if err := logging.LogPanicWithStack(log, "checkAndLog", err); err != nil {
			log.Log("event", "warning", "msg", "faild to write panic file", "err", err)
		}
	}
}

func New(log logging.Interface, id refs.FeedRef) ssb.Plugin {
	return plugin{handler{
		log: log,
		id:  id,
	}}
}

type plugin struct {
	h handler
}

func (plugin) Name() string { return "whoami" }

func (plugin) Method() muxrpc.Method { return method }

func (wami plugin) Handler() muxrpc.Handler { return wami.h }

func (plugin) WrapEndpoint(edp muxrpc.Endpoint) interface{} {
	return endpoint{edp}
}

type handler struct {
	log logging.Interface
	id  refs.FeedRef
}

func (handler) Handled(m muxrpc.Method) bool { return m.String() == "whoami" }

func (handler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}

func (h handler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	type ret struct {
		ID string `json:"id"`
	}

	err := req.Return(ctx, ret{h.id.String()})
	checkAndLog(h.log, err)
}

type endpoint struct {
	edp muxrpc.Endpoint
}

func (edp endpoint) WhoAmI(ctx context.Context) (refs.FeedRef, error) {
	var resp struct {
		ID refs.FeedRef `json:"id"`
	}

	err := edp.edp.Async(ctx, &resp, muxrpc.TypeJSON, method)
	if err != nil {
		return refs.FeedRef{}, fmt.Errorf("error making async call: %w", err)
	}

	return resp.ID, nil
}
