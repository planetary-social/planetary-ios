// SPDX-License-Identifier: MIT

package badger

import (
	"bytes"
	"errors"
	"fmt"

	"github.com/dgraph-io/badger/v3"
	"go.cryptoscope.co/margaret/internal/persist"
)

func (s BadgerSaver) Put(key persist.Key, data []byte) error {
	actualKey := append(s.keyPrefix, []byte(key)...)

	return s.db.Update(func(txn *badger.Txn) error {
		return txn.Set(actualKey, data)
	})
}

func (s BadgerSaver) PutMultiple(values []persist.KeyValuePair) error {
	// badger can only deal with ~18600 set operations in a single transition
	splitted := chunks(values, 18000)
	for i, chunk := range splitted {
		err := s.putMultiple(chunk)
		if err != nil {
			return fmt.Errorf("badger/putMultiple: chunk %d of %d failed: %w", i, len(splitted), err)
		}
	}
	return nil
}

func (s BadgerSaver) putMultiple(values []persist.KeyValuePair) error {
	return s.db.Update(func(txn *badger.Txn) error {
		for i, kv := range values {
			actualKey := append(s.keyPrefix, []byte(kv.Key)...)
			err := txn.Set(actualKey, kv.Value)
			if err != nil {
				return fmt.Errorf("failed to set entry %d of %d (%s): %w", i, len(values), kv.Key, err)
			}
		}
		return nil
	})
}

// splits up the passed slice into chunks of a specific sice
func chunks(pairs []persist.KeyValuePair, chunkSize int) [][]persist.KeyValuePair {
	if len(pairs) == 0 {
		return nil
	}
	divided := make([][]persist.KeyValuePair, (len(pairs)+chunkSize-1)/chunkSize)
	prev := 0 // previous start of a chunk
	i := 0    // how many chunks we processed
	till := len(pairs) - chunkSize
	for prev < till {
		next := prev + chunkSize
		divided[i] = pairs[prev:next]
		prev = next
		i++
	}
	divided[i] = pairs[prev:] // rest (ie final chunk)
	return divided
}

func (s BadgerSaver) Get(key persist.Key) ([]byte, error) {
	actualKey := append(s.keyPrefix, []byte(key)...)

	var data []byte
	err := s.db.View(func(txn *badger.Txn) error {
		it, err := txn.Get(actualKey)
		if err != nil {
			return err
		}
		data, err = it.ValueCopy(nil)
		if err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, badger.ErrKeyNotFound) {
			return nil, persist.ErrNotFound
		}
		return nil, err
	}

	if len(data) == 0 {
		return nil, persist.ErrNotFound
	}

	return data, nil
}

func (s BadgerSaver) List() ([]persist.Key, error) {
	var keys []persist.Key

	err := s.db.Update(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		for iter.Rewind(); iter.Valid(); iter.Next() {
			it := iter.Item()

			k := it.Key()

			if !bytes.HasPrefix(k, s.keyPrefix) {
				continue
			}

			k = bytes.TrimPrefix(k, s.keyPrefix)

			// we need to make a copy of the key since badger reuses the slice on the next iteration
			var trimmedKey = make([]byte, len(k))
			copy(trimmedKey, k)

			keys = append(keys, persist.Key(trimmedKey))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return keys, nil
}

func (s BadgerSaver) Delete(rm persist.Key) error {
	actualKey := append(s.keyPrefix, []byte(rm)...)
	return s.db.Update(func(txn *badger.Txn) error {
		return txn.Delete(actualKey)
	})
}
