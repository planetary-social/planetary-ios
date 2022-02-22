// SPDX-FileCopyrightText: 2021 The margaret Authors
//
// SPDX-License-Identifier: MIT

package multilog

import (
	"errors"
	"io"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/indexes"
)

var (
	ErrSublogNotFound = errors.New("multilog: requested sublog not found")
	ErrSublogDeleted  = errors.New("multilog: stored sublog was deleted. please re-open")
)

// MultiLog is a collection of logs, keyed by a indexes.Addr
type MultiLog interface {
	Get(indexes.Addr) (margaret.Log, error)
	List() ([]indexes.Addr, error)

	io.Closer

	Flush() error

	// Delete removes all entries related to that log
	Delete(indexes.Addr) error
}

func Has(mlog MultiLog, addr indexes.Addr) (bool, error) {
	slog, err := mlog.Get(addr)
	if err != nil {
		return false, err
	}

	return slog.Seq() != margaret.SeqEmpty, nil
}
