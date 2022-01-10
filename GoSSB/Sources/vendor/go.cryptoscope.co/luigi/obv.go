// SPDX-License-Identifier: MIT

package luigi // import "go.cryptoscope.co/luigi"

import (
	"context"
	"sync"
)

// TODO should Observable Set and Value get a ctx?
// TODO should Observable really be an interface? Why? Why not?

// Observabe wraps an interface{} value and allows tracking changes to it
type Observable interface {
	// Broadcast allows subscribing to changes
	Broadcast

	// Set sets a new value
	Set(interface{}) error

	// Value returns the current value
	Value() (interface{}, error)
}

// NewObservable returns a new Observable
func NewObservable(v interface{}) Observable {
	bcstSink, bcst := NewBroadcast()

	return &observable{
		Broadcast: bcst,
		sink:      bcstSink,
		v:         v,
	}
}

// observable is a concrete type implementing Observable
type observable struct {
	sync.Mutex
	Broadcast
	sink Sink

	v interface{}
}

// Set sets a new value
func (o *observable) Set(v interface{}) error {
	o.Lock()
	defer o.Unlock()

	o.v = v
	return o.sink.Pour(context.TODO(), v)
}

// Value returns the current value
func (o *observable) Value() (interface{}, error) {
	o.Lock()
	defer o.Unlock()

	return o.v, nil
}

// Register implements the Broadcast interface.
func (o *observable) Register(sink Sink) func() {
	o.Lock() // is released when goroutine finishes

	var (
		// protects cancel
		lock sync.Mutex

		// registration cancel from broadcast
		cancel func()
	)

	ctx, ctxCancel := context.WithCancel(context.Background())
	// pour current value in the background
	go func(v interface{}) {
		defer o.Unlock()

		err := sink.Pour(ctx, v)
		// TODO at least log this error...or find out what to do with it. maybe
		// change Broadcast interface to let Register return an error?
		if err != nil {
			// TODO maybe also handle the error from Close...or just let it slip
			// because we can't handle it anyway?
			sink.Close()
			return
		}

		lock.Lock()
		defer lock.Unlock()
		cancel = o.Broadcast.Register(sink)
	}(o.v)

	// return a cancel func that cancels both the context and the registration (if set)
	return func() {
		ctxCancel()

		lock.Lock()
		defer lock.Unlock()
		if cancel != nil {
			cancel()
		}
	}
}
