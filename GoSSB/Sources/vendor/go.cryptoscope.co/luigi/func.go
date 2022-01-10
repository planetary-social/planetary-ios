// SPDX-License-Identifier: MIT

package luigi // import "go.cryptoscope.co/luigi"

import (
	"context"
)

// FuncSink defines a function which can be used as a Sink.
type FuncSink func(ctx context.Context, v interface{}, err error) error

// Pour implements the Sink interface.
func (fSink FuncSink) Pour(ctx context.Context, v interface{}) error {
	return fSink(ctx, v, nil)
}

// Close implements the Sink interface.
func (fSink FuncSink) Close() error {
	return fSink(nil, nil, EOS{})
}

func (fSink FuncSink) CloseWithError(err error) error {
	return fSink(nil, nil, err)
}

// FuncSource defines a function which can be used as a Source.
type FuncSource func(context.Context) (interface{}, error)

// Next implements the Pour interface.
func (fSink FuncSource) Next(ctx context.Context) (interface{}, error) {
	return fSink(ctx)
}
