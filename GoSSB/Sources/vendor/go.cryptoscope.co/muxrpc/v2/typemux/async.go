package typemux

import (
	"context"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
)

var _ AsyncHandler = (*AsyncFunc)(nil)

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

func (hm asyncStub) HandleCall(ctx context.Context, req *muxrpc.Request) {
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

func (hm asyncStub) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
	if ch, ok := hm.h.(muxrpc.ConnectHandler); ok {
		ch.HandleConnect(ctx, edp)
	}
}
