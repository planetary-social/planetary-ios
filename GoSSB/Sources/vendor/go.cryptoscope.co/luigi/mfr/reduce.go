// SPDX-License-Identifier: MIT

package mfr // import "go.cryptoscope.co/luigi/mfr"

import (
	"context"
	"errors"
	"sync"

	"go.cryptoscope.co/luigi"
)

// ReduceFunc is a function that reduces a value v and an accumulator to the next accumulator value.
type ReduceFunc func(ctx context.Context, acc, v interface{}) (interface{}, error)

// ReduceSink is a type that reduces values into an accumulator that can be observed using the Observable methods.
type ReduceSink interface {
	luigi.Sink
	luigi.Observable
}

// NewReduceSink returns a ReduceSink that uses the passed reduce function.
func NewReduceSink(f ReduceFunc) ReduceSink {
	return &reduceSink{
		Observable: luigi.NewObservable(nil),
		f:          f,
	}
}

type reduceSink struct {
	luigi.Observable

	f      ReduceFunc
	l      sync.Mutex
	closed bool
}

// Pour updates the accumulator
func (sink *reduceSink) Pour(ctx context.Context, v interface{}) error {
	sink.l.Lock()
	defer sink.l.Unlock()

	if sink.closed {
		return errors.New("write to closed sink")
	}

	acc, err := sink.Value()
	if err != nil {
		return err
	}

	acc, err = sink.f(ctx, acc, v)
	if err != nil {
		return err
	}

	return sink.Observable.Set(acc)
}

// Close closes the sink, prohibiting further writes
func (sink *reduceSink) Close() error {
	sink.l.Lock()
	defer sink.l.Unlock()

	if sink.closed {
		return errors.New("closing closed sink")
	}

	sink.closed = true
	return nil
}

// Set retuns an error. All writes to the observable are performed by the sink.
func (sink *reduceSink) Set(interface{}) error {
	return errors.New("read-only observable")
}
