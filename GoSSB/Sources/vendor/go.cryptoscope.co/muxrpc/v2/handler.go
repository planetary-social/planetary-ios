// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"fmt"
)

//go:generate counterfeiter -o fakehandler_test.go . Handler

// Handler allows handling connections.
// When we are being called, HandleCall is called.
// When a connection is established, HandleConnect is called.
// TODO: let HandleCall return an error
type Handler interface {

	// Handled returns true if the method is handled by the handler
	Handled(Method) bool

	CallHandler
	ConnectHandler
}

type CallHandler interface {
	HandleCall(ctx context.Context, req *Request)
}

type ConnectHandler interface {
	HandleConnect(ctx context.Context, edp Endpoint)
}

type HandlerWrapper func(Handler) Handler

func ApplyHandlerWrappers(h Handler, hws ...HandlerWrapper) Handler {
	for _, hw := range hws {
		h = hw(h)
	}

	return h
}

type HandlerMux struct {
	handlers map[string]Handler
}

func (hm *HandlerMux) Handled(m Method) bool {
	for _, h := range hm.handlers {
		if h.Handled(m) {
			return true
		}
	}
	return false
}

func (hm *HandlerMux) HandleCall(ctx context.Context, req *Request) {
	for i := len(req.Method); i > 0; i-- {
		m := req.Method[:i]
		h, ok := hm.handlers[m.String()]
		if ok {
			h.HandleCall(ctx, req)
			return
		}
	}

	req.CloseWithError(fmt.Errorf("no such method: %s", req.Method))
}

func (hm *HandlerMux) HandleConnect(ctx context.Context, edp Endpoint) {
	for _, h := range hm.handlers {
		go h.HandleConnect(ctx, edp)
	}
}

var _ Handler = (*HandlerMux)(nil)

func (hm *HandlerMux) Register(m Method, h Handler) {
	if hm.handlers == nil {
		hm.handlers = make(map[string]Handler)
	}

	hm.handlers[m.String()] = h
}
