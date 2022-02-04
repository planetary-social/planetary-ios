// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package keys

import (
	"bytes"
	"context"
	"fmt"

	librarian "go.cryptoscope.co/margaret/indexes"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

// Q: what's the relation of ID and key?
// A: id is anything we want to use to store and find a key,
// like the id in a database or key in a k:v store.

type Store struct {
	Index librarian.SetterIndex
}

var todoCtx = context.TODO()

func (mgr *Store) AddKey(id ID, r Recipient) error {
	if !r.Scheme.Valid() {
		return Error{Code: ErrorCodeInvalidKeyScheme, Scheme: r.Scheme}
	}

	idxk := &idxKey{
		ks: r.Scheme,
		id: id,
	}

	idxkBytes, err := idxk.MarshalBinary()
	if err != nil {
		return fmt.Errorf("keys/store failed to martial index key: %w", err)
	}

	recps, err := mgr.GetKeys(r.Scheme, id)
	if err != nil {
		if IsNoSuchKey(err) {
			recps = Recipients{}
		} else {
			return fmt.Errorf("error getting old value: %w", err)
		}
	}

	// add new key to existing ones
	recps = append(recps, r)

	return mgr.Index.Set(todoCtx, librarian.Addr(idxkBytes), recps)
}

func (mgr *Store) SetKey(id ID, r Recipient) error {
	if !r.Scheme.Valid() {
		return Error{Code: ErrorCodeInvalidKeyScheme, Scheme: r.Scheme}
	}

	idxk := &idxKey{
		ks: r.Scheme,
		id: id,
	}

	idxkBs, err := idxk.MarshalBinary()
	if err != nil {
		return err
	}

	return mgr.Index.Set(todoCtx, librarian.Addr(idxkBs), Recipients{r})
}

func (mgr *Store) RmKeys(ks KeyScheme, id ID) error {
	idxk := &idxKey{
		ks: ks,
		id: id,
	}

	idxkBs, err := idxk.MarshalBinary()
	if err != nil {
		return err
	}

	return mgr.Index.Delete(todoCtx, librarian.Addr(idxkBs))
}

func (mgr *Store) RmKey(ks KeyScheme, id ID, rmKey Recipient) error {
	// load current value
	recps, err := mgr.GetKeys(ks, id)
	if err != nil {
		return fmt.Errorf("error getting current value: %w", err)
	}

	// look for rmKey
	var idx int = -1
	for i, r := range recps {
		if bytes.Equal(r.Key, rmKey.Key) {
			idx = i
			break
		}
	}

	if idx < 0 {
		return fmt.Errorf("recpient not in keys list")
	}

	recps = append(recps[:idx], recps[idx+1:]...)

	// update stored entry
	idxk := &idxKey{
		ks: ks,
		id: id,
	}

	idxkBs, err := idxk.MarshalBinary()
	if err != nil {
		return err
	}

	return mgr.Index.Set(todoCtx, librarian.Addr(idxkBs), recps)
}

func (mgr *Store) GetKeysForMessage(ks KeyScheme, msg refs.MessageRef) (Recipients, error) {
	idBytes, err := tfk.Encode(msg)
	if err != nil {
		return nil, err
	}
	return mgr.getKeys(ks, ID(idBytes))
}

func (mgr *Store) GetKeys(ks KeyScheme, id ID) (Recipients, error) {
	return mgr.getKeys(ks, id)
}

func (mgr *Store) getKeys(ks KeyScheme, id ID) (Recipients, error) {
	if !ks.Valid() {
		return nil, Error{Code: ErrorCodeInvalidKeyScheme, Scheme: ks}
	}

	idxk := &idxKey{
		ks: ks,
		id: id,
	}

	idxkBs, err := idxk.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("key store: failed to marshal index key: %w", err)
	}

	data, err := mgr.Index.Get(todoCtx, librarian.Addr(idxkBs))
	if err != nil {
		return nil, fmt.Errorf("key store: failed to get data from index: %w", err)
	}

	ksIface, err := data.Value()
	if err != nil {
		return nil, fmt.Errorf("key store: failed to unpack index data: %w", err)
	}

	switch tv := ksIface.(type) {
	case Recipients:
		return tv, nil
	case librarian.UnsetValue:
		return nil, Error{
			Code:   ErrorCodeNoSuchKey,
			Scheme: ks,
			ID:     id,
		}
	default:
		return nil, fmt.Errorf("keys store: expected type %T, got %T", Recipients{}, ksIface)
	}

}
