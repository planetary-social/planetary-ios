// SPDX-License-Identifier: MIT

package luigi // import "go.cryptoscope.co/luigi"

import (
	"context"

	"github.com/pkg/errors"
)

// EOS stands for End Of Stream.  It signals when a non-blocking stream is
// empty, or a stream is closed.
//
// Similar the io package's EOF.
type EOS struct{}

func (_ EOS) Error() string { return "end of stream" }

// IsEOS checks whether the error is due to a closed stream.
func IsEOS(err error) bool {
	err = errors.Cause(err)

	_, ok := err.(EOS)
	return ok
}

// Sink is the interface which wraps methods writing to a stream.
type Sink interface {
	Pour(ctx context.Context, v interface{}) error
	Close() error
}

type ErrorCloser interface {
	CloseWithError(error) error
}

// Source is the interface which wraps the Next method for reading from a stream.
type Source interface {
	Next(context.Context) (obj interface{}, err error)
}

// PushSource is the interface for requesting all content be written to the
// given sink.
type PushSource interface {
	Push(ctx context.Context, dst Sink) error
}

// Pump moves values from a source into a sink.
//
// Currently this doesn't work atomically, so if a Sink errors in the
// Pour call, the value that was read from the source is lost.
func Pump(ctx context.Context, dst Sink, src Source) error {
	if psrc, ok := src.(PushSource); ok {
		return psrc.Push(ctx, dst)
	}

	for {
		v, err := src.Next(ctx)
		if IsEOS(err) {
			return nil
		} else if err != nil {
			return err
		}

		err = dst.Pour(ctx, v)
		if err != nil {
			return err
		}
	}

	panic("unreachable")
}
