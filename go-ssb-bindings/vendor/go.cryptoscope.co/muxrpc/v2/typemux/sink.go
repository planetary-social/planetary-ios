package typemux

import (
	"context"

	"go.cryptoscope.co/muxrpc/v2"
)

var _ SinkHandler = (*SinkFunc)(nil)

// SinkFunc is a utility to fulfill SinkHandler just as a function, not a type with the named method
type SinkFunc func(context.Context, *muxrpc.Request, *muxrpc.ByteSource) error

// HandleSink implements the sink handler for the function
func (sf SinkFunc) HandleSink(ctx context.Context, r *muxrpc.Request, src *muxrpc.ByteSource) error {
	return sf(ctx, r, src)
}

// SinkHandler initiates a 'sink' call. The handler receives data from the peer through the passed source
type SinkHandler interface {
	HandleSink(context.Context, *muxrpc.Request, *muxrpc.ByteSource) error
}

type sinkStub struct {
	h SinkHandler
}

func (hm sinkStub) HandleCall(ctx context.Context, req *muxrpc.Request) {
	// TODO: check call type

	src, err := req.ResponseSource()
	if err != nil {
		req.CloseWithError(err)
		return
	}

	err = hm.h.HandleSink(ctx, req, src)
	if err != nil {
		req.CloseWithError(err)
		return
	}
}

func (hm sinkStub) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
	if ch, ok := hm.h.(muxrpc.ConnectHandler); ok {
		ch.HandleConnect(ctx, edp)
	}
}
