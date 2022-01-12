// SPDX-License-Identifier: MIT

package multilog

import (
	"io"

	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"
)

var ErrSublogDeleted = errors.Errorf("multilog: stored sublog was deleted. please re-open")

// MultiLog is a collection of logs, keyed by a librarian.Addr
// TODO maybe only call this log to avoid multilog.MultiLog?
type MultiLog interface {
	Get(librarian.Addr) (margaret.Log, error)
	List() ([]librarian.Addr, error)

	io.Closer

	Flush() error

	// Delete removes all entries related to that log
	Delete(librarian.Addr) error
}

func Has(mlog MultiLog, addr librarian.Addr) (bool, error) {
	slog, err := mlog.Get(addr)
	if err != nil {
		return false, err
	}

	seqVal, err := slog.Seq().Value()
	if err != nil {
		return false, err
	}

	return seqVal.(margaret.BaseSeq) != margaret.SeqEmpty, nil
}
