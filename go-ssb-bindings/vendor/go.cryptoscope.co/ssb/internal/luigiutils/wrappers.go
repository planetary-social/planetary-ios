// SPDX-License-Identifier: MIT

package luigiutils

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/codec"
	"go.cryptoscope.co/ssb/message/multimsg"
)

// NewGabbyStreamSink expects the values passing through to be of type multimsg.MultiMessage
// it then unpacks them as gabygrove, reencodes the transfer object to bytes
// and passes those as muxrpc codec.Body to the wrapped sink
func NewGabbyStreamSink(stream luigi.Sink) luigi.Sink {
	wrappedSink := luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			if luigi.IsEOS(err) {
				return nil
			}
			return err
		}
		var mm *multimsg.MultiMessage
		switch tv := v.(type) {
		case *multimsg.MultiMessage:
			mm = tv
		case multimsg.MultiMessage:
			mm = &tv
		default:
			return errors.Errorf("gabbyStream: expected MultiMessage - got %T", v)
		}

		tr, ok := mm.AsGabby()
		if !ok {
			return errors.Errorf("gabbyStream: wrong format type type")
		}

		trdata, err := tr.MarshalCBOR()
		if err != nil {
			return errors.Wrap(err, "gabbyStream: failed to marshal transfer object")
		}

		return stream.Pour(ctx, codec.Body(trdata))
	})
	return &wrappedSink
}

// NewSinkCounter returns a new Sink which increases the given counter when poured to.
// warning: also counts errored pour calls on the wrapped sink
func NewSinkCounter(counter *int, sink luigi.Sink) luigi.FuncSink {
	return func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			return err
		}

		*counter++
		return sink.Pour(ctx, v)
	}
}
