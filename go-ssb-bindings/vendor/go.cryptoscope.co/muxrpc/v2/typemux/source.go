package typemux

import (
	"context"

	"go.cryptoscope.co/muxrpc/v2"
)

var _ SourceHandler = (*SourceFunc)(nil)

type SourceFunc func(context.Context, *muxrpc.Request, *muxrpc.ByteSink) error

func (sf SourceFunc) HandleSource(ctx context.Context, r *muxrpc.Request, src *muxrpc.ByteSink) error {
	return sf(ctx, r, src)
}

// SourceHandler initiates a 'source' call, so the handler is supposed to send a stream of stuff to the peer.
type SourceHandler interface {
	HandleSource(context.Context, *muxrpc.Request, *muxrpc.ByteSink) error
}

type sourceStub struct {
	h SourceHandler
}

func (hm sourceStub) HandleCall(ctx context.Context, req *muxrpc.Request) {
	// TODO: check call type

	w, err := req.ResponseSink()
	if err != nil {
		req.CloseWithError(err)
		return
	}

	err = hm.h.HandleSource(ctx, req, w)
	if err != nil {
		req.CloseWithError(err)
		return
	}
}

func (hm sourceStub) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
	if ch, ok := hm.h.(muxrpc.ConnectHandler); ok {
		ch.HandleConnect(ctx, edp)
	}
}
