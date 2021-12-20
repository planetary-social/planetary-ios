// SPDX-License-Identifier: MIT

package badger

import (
	"fmt"

	"github.com/dgraph-io/badger/v3"
	"go.cryptoscope.co/margaret/internal/persist"
)

type BadgerSaver struct {
	db *badger.DB

	// shared means the backing db is shared with other indexes
	// this controls the closing behavior.
	// shared instances need to be closed independantly.
	shared bool

	keyPrefix []byte
}

var _ persist.Saver = (*BadgerSaver)(nil)

// Close closes the backing database if it's not shared.
func (sl *BadgerSaver) Close() error {
	if sl.shared {
		return nil
	}
	return sl.db.Close()
}

// NewStandalone opens
func NewStandalone(path string) (*BadgerSaver, error) {
	var ms BadgerSaver

	var err error

	o := badger.DefaultOptions(path)
	ms.db, err = badger.Open(o)
	if err != nil {
		return nil, fmt.Errorf("failed to create KV %s: %w", path, err)
	}

	return &ms, nil
}

func NewShared(db *badger.DB, keyPrefix []byte) (*BadgerSaver, error) {
	var ms BadgerSaver
	ms.db = db
	ms.shared = true
	ms.keyPrefix = keyPrefix
	return &ms, nil
}
