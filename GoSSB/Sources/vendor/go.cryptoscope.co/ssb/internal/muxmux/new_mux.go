package muxmux

import (
	"context"

	"github.com/go-kit/kit/log"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc"
)

// SinkHandler initiates a 'sink' call. The handler receives stuff from the peer through the passed source
type SinkHandler interface {
	HandleSource(context.Context, *muxrpc.Request, luigi.Source) error
}

type DuplexHandler interface {
	HandleSource(context.Context, *muxrpc.Request, luigi.Source, luigi.Sink) error
}

type HandlerMux struct {
	logger log.Logger

	handlers map[string]muxrpc.Handler
}

func New(log log.Logger) HandlerMux {
	return HandlerMux{
		handlers: make(map[string]muxrpc.Handler),
		logger:   log,
	}
}

func (hm *HandlerMux) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	for i := len(req.Method); i > 0; i-- {
		m := req.Method[:i]
		h, ok := hm.handlers[m.String()]
		if ok {
			h.HandleCall(ctx, req, edp)
			return
		}
	}
	req.Stream.CloseWithError(errors.Errorf("no such command: %v", req.Method))
}

// HandleConnect does nothing on this mux since it's only intended for function calls, not connect events
func (hm *HandlerMux) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}

// RegisterAsync registers a 'async' call for name method
func (hm *HandlerMux) RegisterAsync(m muxrpc.Method, h AsyncHandler) {
	hm.handlers[m.String()] = asyncStub{
		logger: hm.logger,
		h:      h,
	}
}

// RegisterSource registers a 'source' call for name method
func (hm *HandlerMux) RegisterSource(m muxrpc.Method, h SourceHandler) {
	hm.handlers[m.String()] = sourceStub{
		logger: hm.logger,
		h:      h,
	}
}
