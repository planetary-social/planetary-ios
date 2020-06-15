package muxmux

import (
	"context"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"go.cryptoscope.co/muxrpc"
)

type AsyncFunc func(context.Context, *muxrpc.Request) (interface{}, error)

func (af AsyncFunc) HandleAsync(ctx context.Context, r *muxrpc.Request) (interface{}, error) {
	return af(ctx, r)
}

type AsyncHandler interface {
	HandleAsync(context.Context, *muxrpc.Request) (interface{}, error)
}

type asyncStub struct {
	logger log.Logger

	h AsyncHandler
}

func (hm asyncStub) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	// TODO: check call type?

	v, err := hm.h.HandleAsync(ctx, req)
	if err != nil {
		req.CloseWithError(err)
		return
	}

	err = req.Return(ctx, v)
	if err != nil {
		level.Error(hm.logger).Log("evt", "return failed", "err", err, "method", req.Method.String())
	}
}

func (hm asyncStub) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}
