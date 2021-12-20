// Package typemux offers an improved muxrpc.HandlerMux (think HTTP router).
// compared to the first draft, this one offers specialed handler functions for the different call types (async, source, sink)
// to reduce boilerplate in handlers.
package typemux

import (
	"context"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
)

// the handlers passed to typemux are checked bu this muxer and dont need the Handled() function
type handler interface {
	muxrpc.CallHandler
	muxrpc.ConnectHandler
}

type HandlerMux struct {
	logger log.Logger

	handlers map[string]handler
}

var _ muxrpc.Handler = (*HandlerMux)(nil)

func New(log log.Logger) HandlerMux {
	return HandlerMux{
		handlers: make(map[string]handler),
		logger:   log,
	}
}

func (hm *HandlerMux) Handled(m muxrpc.Method) bool {
	_, has := hm.handlers[m.String()]
	return has
}

func (hm *HandlerMux) HandleCall(ctx context.Context, req *muxrpc.Request) {
	for i := len(req.Method); i > 0; i-- {
		m := req.Method[:i]
		h, ok := hm.handlers[m.String()]
		if ok {
			h.HandleCall(ctx, req)
			return
		}
	}
	req.CloseWithError(fmt.Errorf("no such command: %v", req.Method))
}

func (hm *HandlerMux) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
	for _, h := range hm.handlers {
		go h.HandleConnect(ctx, edp)
	}
}

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
		// logger: hm.logger,
		h: h,
	}
}

// RegisterSink registers a 'sink' call for name method
func (hm *HandlerMux) RegisterSink(m muxrpc.Method, h SinkHandler) {
	hm.handlers[m.String()] = sinkStub{
		// logger: hm.logger,
		h: h,
	}
}

// RegisterDuplex registers a 'sink' call for name method
func (hm *HandlerMux) RegisterDuplex(m muxrpc.Method, h DuplexHandler) {
	hm.handlers[m.String()] = duplexStub{
		// logger: hm.logger,
		h: h,
	}
}
