package badger

import (
	"github.com/dgraph-io/badger/v3"

	pbadger "go.cryptoscope.co/margaret/internal/persist/badger"
	"go.cryptoscope.co/margaret/multilog/roaring"
)

func NewStandalone(base string) (*roaring.MultiLog, error) {
	s, err := pbadger.NewStandalone(base)
	if err != nil {
		return nil, err
	}
	return roaring.NewStore(s), nil
}

func NewShared(db *badger.DB, keyPrefix []byte) (*roaring.MultiLog, error) {
	s, err := pbadger.NewShared(db, keyPrefix)
	if err != nil {
		return nil, err
	}
	return roaring.NewStore(s), nil
}
