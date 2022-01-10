// SPDX-License-Identifier: MIT

package margaret // import "go.cryptoscope.co/margaret"

import (
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
)

// Log stores entries sequentially, which can be queried individually using Get or as streams using Query.
type Log interface {
	// Seq returns an observable that holds the current sequence number
	Seq() luigi.Observable

	// Get returns the entry with sequence number seq
	Get(seq Seq) (interface{}, error)

	// Query returns a stream that is constrained by the passed query specification
	Query(...QuerySpec) (luigi.Source, error)

	// Append appends a new entry to the log
	Append(interface{}) (Seq, error)
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
	Null(Seq) error

	Replace(Seq, []byte) error
}

type errNulled bool

var ErrNulled errNulled

func (errNulled) Error() string {
	return "margaret: Entry Nulled"
}

func IsErrNulled(err error) bool {
	switch errors.Cause(err).(type) {
	case errNulled:
		return true
	default:
		return false
	}
}
