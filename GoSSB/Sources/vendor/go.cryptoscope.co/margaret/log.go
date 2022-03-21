// SPDX-FileCopyrightText: 2021 The margaret Authors
//
// SPDX-License-Identifier: MIT

package margaret // import "go.cryptoscope.co/margaret"

import (
	"errors"

	"go.cryptoscope.co/luigi"
)

// Log stores entries sequentially, which can be queried individually using Get or as streams using Query.
type Log interface {
	// Seq returns the current sequence number, which is also the number of entries in the log
	Seqer

	// Changes returns an observable that holds the current sequence number
	Changes() luigi.Observable

	// Get returns the entry with sequence number seq
	Get(seq int64) (interface{}, error)

	// Query returns a stream that is constrained by the passed query specification
	Query(...QuerySpec) (luigi.Source, error)

	// Append appends a new entry to the log
	Append(interface{}) (int64, error)
}

type oob struct{}

// OOB is an out of bounds error
var OOB oob

func (oob) Error() string {
	return "out of bounds"
}

// IsOutOfBounds returns whether a particular error is an out-of-bounds error
func IsOutOfBounds(err error) bool {
	_, ok := err.(oob)
	return ok
}

type Alterer interface {
	Null(int64) error

	Replace(int64, []byte) error
}

var ErrNulled = errors.New("margaret: Entry Nulled")

func IsErrNulled(err error) bool {
	return errors.Is(err, ErrNulled)
}
