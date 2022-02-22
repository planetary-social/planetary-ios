// SPDX-FileCopyrightText: 2021 The margaret Authors
//
// SPDX-License-Identifier: MIT

package indexes

import (
	"context"
	"fmt"

	"io"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
)

// Addr is an address (or key) in the index.
// TODO maybe not use a string but a Stringer or
type Addr string

func (a Addr) String() string {
	return fmt.Sprintf("index-address:%q", string(a))
}

// Index provides an index table keyed by Addr.
// Often also implements Setter.
type Index interface {
	// Get returns the an observable of the value stored at the address.
	// Getting an unset value retuns a valid Observable with a value
	// of type Unset and a nil error.
	Get(context.Context, Addr) (luigi.Observable, error)
}

// UnsetValue is the value of observable returned by idx.Get() when the
// requested address has not been set yet.
type UnsetValue struct {
	Addr Addr
}

type Setter interface {
	// Set sets a value in the index
	Set(context.Context, Addr, interface{}) error

	// Delete deletes a value from the index
	Delete(context.Context, Addr) error
}

// SetterIndex is an index that can be updated using calls to Set and Delete.
type SetterIndex interface {
	Index
	Setter

	Flush() error
}

// SinkIndex is an index that is updated by processing a stream.
type SinkIndex interface {
	luigi.Sink

	QuerySpec() margaret.QuerySpec
}

type SeqSetterIndex interface {
	SetterIndex

	SetSeq(int64) error
	GetSeq() (int64, error)

	io.Closer
}

// TODO maybe provide other index builders as well, e.g. for managing
// sets: add and remove values from and to sets, stored at address
