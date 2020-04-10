// SPDX-License-Identifier: MIT

package replicate

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc"

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

func (g replicateHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (g replicateHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	if len(req.Method) < 2 && req.Method[1] != "upto" {
		req.CloseWithError(errors.Errorf("invalid method"))
		return
	}

	src, err := ssb.FeedsWithSequnce(g.users)
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "replicate: did not get feed source"))
		return
	}

	err = luigi.Pump(ctx, req.Stream, src)
	if err != nil {
		req.CloseWithError(errors.Wrapf(err, "replicate: failed to pump feed statuses"))
		return

	}

	req.Stream.Close()
}
