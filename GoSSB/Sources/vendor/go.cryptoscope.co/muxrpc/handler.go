package muxrpc

import (
	"context"
	"sync"

	"github.com/pkg/errors"
)

// Handler allows handling connections.
// When we are being called, HandleCall is called.
// When a connection is established, HandleConnect is called.
// TODO: let HandleCall return an error
type Handler interface {
	HandleCall(ctx context.Context, req *Request, edp Endpoint)
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
	regLock  sync.Mutex // protects the map
	handlers map[string]Handler
}

func (hm *HandlerMux) HandleCall(ctx context.Context, req *Request, edp Endpoint) {
	// hm.regLock.Lock()
	// defer hm.regLock.Unlock()
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

func (hm *HandlerMux) HandleConnect(ctx context.Context, edp Endpoint) {
	// hm.regLock.Lock()
	// defer hm.regLock.Unlock()
	var wg sync.WaitGroup
	wg.Add(len(hm.handlers))

	for _, h := range hm.handlers {
		go func(h Handler) {

			h.HandleConnect(ctx, edp)
			wg.Done()
		}(h)
	}

	wg.Wait()
}

func (hm *HandlerMux) Register(m Method, h Handler) {
	hm.regLock.Lock()
	defer hm.regLock.Unlock()
	if hm.handlers == nil {
		hm.handlers = make(map[string]Handler)
	}

	hm.handlers[m.String()] = h
}

type NamedHandler struct {
	Method  Method
	Handler Handler
}

func (hm *HandlerMux) RegisterAll(handlers ...NamedHandler) {
	hm.regLock.Lock()
	defer hm.regLock.Unlock()
	if hm.handlers == nil {
		hm.handlers = make(map[string]Handler)
	}

	for _, hn := range handlers {
		hm.handlers[hn.Method.String()] = hn.Handler
	}

}
