// SPDX-License-Identifier: MIT

package gossip

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/codec"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/message/multimsg"
)

func gabbyStreamSink(stream luigi.Sink) luigi.Sink {
	return luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			return err
		}
		mm, ok := v.(*multimsg.MultiMessage)
		if !ok {
			return errors.Errorf("binStream: expected []byte - got %T", v)
		}
		tr, ok := mm.AsGabby()
		if !ok {
			return errors.Errorf("wrong mm type")
		}

		trdata, err := tr.MarshalCBOR()
		if err != nil {
			return errors.Wrap(err, "failed to marshal transfer")
		}

		return stream.Pour(ctx, codec.Body(trdata))
	})
}

func asJSONsink(stream luigi.Sink) luigi.Sink {
	return luigi.FuncSink(func(ctx context.Context, val interface{}, err error) error {
		if err != nil {
			if luigi.IsEOS(err) {
				return stream.Close()
			}
			return err
		}
		msg, ok := val.(ssb.Message)
		if !ok {
			return errors.Errorf("asJSONsink: expected ssb.Message - got %T", val)
		}
		return stream.Pour(ctx, msg.ValueContentJSON())
	})
}

// newSinkCounter returns a new Sink which increases the given counter when poured to.
func newSinkCounter(counter *int, sink luigi.Sink) luigi.FuncSink {
	return func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			return err
		}

		*counter++
		return sink.Pour(ctx, v)
	}
}
