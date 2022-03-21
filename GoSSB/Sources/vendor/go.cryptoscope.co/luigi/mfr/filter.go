// SPDX-License-Identifier: MIT

package mfr // import "go.cryptoscope.co/luigi/mfr"

import (
	"context"

	"go.cryptoscope.co/luigi"
)

// FilterFunc is used as a predicate to select values in a stream.
type FilterFunc func(ctx context.Context, v interface{}) (bool, error)

// SinkFilter returns a new Sink whose values are selected according to the
// given FilterFunc.
func SinkFilter(sink luigi.Sink, f FilterFunc) luigi.Sink {
	return &sinkFilter{
		Sink: sink,
		f:    f,
	}
}

type sinkFilter struct {
	luigi.Sink

	f FilterFunc
}

// Pour implements the luigi.Sink interface.
func (sink *sinkFilter) Pour(ctx context.Context, v interface{}) error {
	pass, err := sink.f(ctx, v)
	if err == nil && pass {
		err = sink.Sink.Pour(ctx, v)
	}

	return err
}

// SinkFilter returns a new Source whose values are filtered according to the
// given FilterFunc.
func SourceFilter(src luigi.Source, f FilterFunc) luigi.Source {
	return &srcFilter{
		Source: src,
		f:      f,
	}
}

type srcFilter struct {
	luigi.Source

	f FilterFunc
}

// Pour implements the luigi.Source interface.
func (src *srcFilter) Next(ctx context.Context) (v interface{}, err error) {
	var pass bool

	for !pass {
		v, err = src.Source.Next(ctx)
		if err != nil {
			return nil, err
		}

		pass, err = src.f(ctx, v)
		if err != nil {
			return nil, err
		}
	}

	return v, nil
}
