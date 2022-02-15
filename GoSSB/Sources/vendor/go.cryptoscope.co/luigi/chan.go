// SPDX-License-Identifier: MIT

package luigi // import "go.cryptoscope.co/luigi"

import (
	"context"
	"sync"

	"github.com/pkg/errors"
)

type pipeOpts struct {
	bufferSize  int
	nonBlocking bool
}

// PipeOpt configures NewPipes behavior
type PipeOpt func(*pipeOpts) error

// WithBuffer sets the buffer size of the internal channel
func WithBuffer(bufSize int) PipeOpt {
	return PipeOpt(func(opts *pipeOpts) error {
		opts.bufferSize = bufSize
		return nil
	})
}

// NonBlocking changes the behavior to assume a non-blocking backing medium
func NonBlocking() PipeOpt {
	return PipeOpt(func(opts *pipeOpts) error {
		opts.nonBlocking = true
		return nil
	})
}

// NewPipe returns both ends of a stream.
func NewPipe(opts ...PipeOpt) (Source, Sink) {
	var pOpts pipeOpts

	for i, opt := range opts {
		err := opt(&pOpts)
		if err != nil {
			// TODO what to do?
			// the current options don't trigger this anyway
			panic(errors.Wrapf(err, "luigi: invalid pipe option %d", i))
		}
	}

	ch := make(chan interface{}, pOpts.bufferSize)

	// TODO: it seems like at this point we could turn closeCh into a chan error
	// and communitcate the closeErr to the other side instead of having a lock to protect the shared closeErr
	closeCh := make(chan struct{})

	var closeLock sync.Mutex
	var closeErr error

	return &chanSource{
			ch:          ch,
			closeCh:     closeCh,
			closeLock:   &closeLock,
			closeErr:    &closeErr,
			nonBlocking: pOpts.nonBlocking,
		}, &chanSink{
			ch:          ch,
			closeCh:     closeCh,
			closeLock:   &closeLock,
			closeErr:    &closeErr,
			nonBlocking: pOpts.nonBlocking,
		}
}

type chanSource struct {
	ch          <-chan interface{}
	nonBlocking bool
	closeLock   *sync.Mutex
	closeCh     chan struct{}
	closeErr    *error
}

// Next implements the Source interface.
func (src *chanSource) Next(ctx context.Context) (v interface{}, err error) {
	if src.nonBlocking { // TODO: make two implementations of this (blocking and non-blocking) to untangle this mess
		select {
		case v = <-src.ch:
		case <-src.closeCh:
			select {
			case v = <-src.ch:
			default:
				src.closeLock.Lock()
				cErr := *(src.closeErr)
				src.closeLock.Unlock()
				if cErr != nil {
					err = cErr
				} else {
					err = EOS{}
				}
			}
		default:
			err = errors.New("channel not ready for reading")
		}
	} else {
		select {
		case v = <-src.ch:
		case <-src.closeCh:
			select {
			case v = <-src.ch:
			default:
				src.closeLock.Lock()
				cErr := *(src.closeErr)
				src.closeLock.Unlock()
				if cErr != nil {
					err = cErr
				} else {
					err = EOS{}
				}
			}
		case <-ctx.Done():
			// even if both the context is cancelled and the stream is closed,
			// we consistently return the closing error
			select {
			case <-src.closeCh:
				src.closeLock.Lock()
				cErr := *(src.closeErr)
				src.closeLock.Unlock()
				if cErr != nil {
					err = cErr
				} else {
					err = EOS{}
				}
			default:
				err = errors.Wrap(ctx.Err(), "luigi next done")
			}
		}
	}

	return v, err
}

type chanSink struct {
	ch          chan<- interface{}
	nonBlocking bool
	closeLock   *sync.Mutex
	closeCh     chan struct{}
	closeErr    *error
	closeOnce   sync.Once
}

// Pour implements the Sink interface.
func (sink *chanSink) Pour(ctx context.Context, v interface{}) error {
	select {
	case <-sink.closeCh:
		return ErrPourToClosedSink
	default:
	}

	// TODO: make two implementations of this (blocking and non-blocking) to untangle this mess
	if sink.nonBlocking {
		select {
		case sink.ch <- v:
			return nil
		case <-sink.closeCh:
			// we may be called with closed context on a closed sink. in that case we want to return the closed sink error.
			select {
			case <-sink.closeCh:
				return ErrPourToClosedSink
			default:
				return ctx.Err()
			}
		default:
			return errors.New("channel not ready for writing")
		}
	} else {
		select {
		case sink.ch <- v:
			return nil
		case <-sink.closeCh:
			return ErrPourToClosedSink
		case <-ctx.Done():
			// we may be called with closed context on a closed sink. in that case we want to return the closed sink error.
			select {
			case <-sink.closeCh:
				return ErrPourToClosedSink
			default:
				return ctx.Err()
			}
		}
	}
}

var ErrPourToClosedSink = errors.New("pour to closed sink")

// Close implements the Sink interface.
func (sink *chanSink) Close() error {
	return sink.CloseWithError(EOS{})
}

func (sink *chanSink) CloseWithError(err error) error {
	sink.closeOnce.Do(func() {
		sink.closeLock.Lock()
		*sink.closeErr = err
		sink.closeLock.Unlock()
		close(sink.closeCh)
	})
	return nil
}
