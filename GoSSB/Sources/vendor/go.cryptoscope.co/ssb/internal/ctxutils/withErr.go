// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package ctxutils

import (
	"context"
	"sync"
)

// WithError returns a cancellable context where ctx.Err() is the passed err instead of "context cancelled"
// TODO: put this somewhere nicer
func WithError(ctx context.Context, err error) (context.Context, context.CancelFunc) {
	ch := make(chan struct{})
	next := &errCtx{
		ch:      ch,
		Context: ctx,
	}

	var once sync.Once

	cls := func() {
		once.Do(func() {
			next.err = err
			close(ch)
		})
	}

	go func() {
		select {
		case <-ctx.Done():
			once.Do(func() {
				next.err = ctx.Err()
				close(ch)
			})
		case <-ch:
		}
	}()

	return next, cls
}

// errCtx is the context that cancels functions and returns a luigi.EOS error
type errCtx struct {
	context.Context

	ch  <-chan struct{}
	err error
}

// Done returns a channel that is closed once the context is cancelled.
func (ctx *errCtx) Done() <-chan struct{} {
	return ctx.ch
}

// Err returns the error that made the context cancel.
// returns luigi.EOS if cancelled using our cancel function or the error
// returned by the context below if that was canceled.
func (ctx *errCtx) Err() error {
	select {
	case <-ctx.ch:
		return ctx.err
	default:
		return nil
	}
}
