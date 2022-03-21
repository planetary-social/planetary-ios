// SPDX-License-Identifier: MIT

package luigi

import (
	"context"
	"errors"
)

// SliceSink binds Source methods to an interface array.
type SliceSource []interface{}

// Next implements the Source interface.
func (src *SliceSource) Next(context.Context) (v interface{}, err error) {
	if len(*src) == 0 {
		return nil, EOS{}
	}

	v, *src = (*src)[0], (*src)[1:]

	return v, nil
}

// SliceSink binds Sink methods to an interface array.
type SliceSink struct {
	slice  *[]interface{}
	closed bool
}

// NewSliceSink returns a new SliceSink bound to the given interface array.
func NewSliceSink(arg *[]interface{}) *SliceSink {
	return &SliceSink{
		slice:  arg,
		closed: false,
	}
}

// Pour implements the Sink interface.  It writes value to a destination Sink.
func (sink *SliceSink) Pour(ctx context.Context, v interface{}) error {
	if sink.closed {
		return errors.New("pour to closed sink")
	}
	*sink.slice = append(*sink.slice, v)
	return nil
}

// Close is a dummy method to implement the Sink interface.
func (sink *SliceSink) Close() error {
	sink.closed = true
	return nil
}
