// SPDX-License-Identifier: MIT

package mkv

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"reflect"
	"sync"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"modernc.org/kv"

	"go.cryptoscope.co/librarian"
)

func NewIndex(db *kv.DB, tipe interface{}) librarian.SeqSetterIndex {
	return &index{
		db:     db,
		tipe:   tipe,
		obvs:   make(map[librarian.Addr]luigi.Observable),
		curSeq: margaret.BaseSeq(-2),
	}
}

type index struct {
	l      sync.Mutex
	db     *kv.DB
	obvs   map[librarian.Addr]luigi.Observable
	tipe   interface{}
	curSeq margaret.Seq
}

func (idx *index) Get(ctx context.Context, addr librarian.Addr) (luigi.Observable, error) {
	idx.l.Lock()
	defer idx.l.Unlock()

	obv, ok := idx.obvs[addr]
	if ok {
		return obv, nil
	}

	t := reflect.TypeOf(idx.tipe)
	v := reflect.New(t).Interface()

	data, err := idx.db.Get(nil, []byte(addr))
	if data == nil {
		obv := librarian.NewObservable(librarian.UnsetValue{addr}, idx.deleter(addr))
		idx.obvs[addr] = obv
		return roObv{obv}, nil
	}
	if err != nil {
		return nil, errors.Wrap(err, "error loading data from store")
	}

	if um, ok := v.(librarian.Unmarshaler); ok {
		if t.Kind() != reflect.Ptr {
			v = reflect.ValueOf(v).Elem().Interface()
		}

		err = um.Unmarshal(data)
		return nil, errors.Wrap(err, "error unmarshaling using custom marshaler")
	}

	err = json.Unmarshal(data, v)
	if err != nil {
		return nil, errors.Wrap(err, "error unmarshaling using json marshaler")
	}

	if t.Kind() != reflect.Ptr {
		v = reflect.ValueOf(v).Elem().Interface()
	}

	obv = librarian.NewObservable(v, idx.deleter(addr))
	idx.obvs[addr] = obv
	return roObv{obv}, nil
}

func (idx *index) deleter(addr librarian.Addr) func() {
	return func() {
		delete(idx.obvs, addr)
	}
}

func (idx *index) Set(ctx context.Context, addr librarian.Addr, v interface{}) error {
	var (
		raw []byte
		err error
	)

	if m, ok := v.(librarian.Marshaler); ok {
		raw, err = m.Marshal()
		if err != nil {
			return errors.Wrap(err, "error marshaling value using custom marshaler")
		}
	} else {
		raw, err = json.Marshal(v)
		if err != nil {
			return errors.Wrap(err, "error marshaling value using json marshaler")
		}
	}

	err = idx.db.Set([]byte(addr), raw)
	if err != nil {
		return errors.Wrap(err, "error in store")
	}

	idx.l.Lock()
	defer idx.l.Unlock()

	obv, ok := idx.obvs[addr]
	if ok {
		err = obv.Set(v)
		err = errors.Wrap(err, "error setting value in observable")
	}

	return err
}

func (idx *index) Delete(ctx context.Context, addr librarian.Addr) error {
	err := idx.db.Delete([]byte(addr))
	if err != nil {
		return errors.Wrap(err, "error in store")
	}

	idx.l.Lock()
	defer idx.l.Unlock()

	obv, ok := idx.obvs[addr]
	if ok {
		err = obv.Set(librarian.UnsetValue{addr})
		err = errors.Wrap(err, "error setting value in observable")
	}

	return err
}

func (idx *index) SetSeq(seq margaret.Seq) error {
	var (
		raw  = make([]byte, 8)
		err  error
		addr librarian.Addr = "__current_observable"
	)

	binary.BigEndian.PutUint64(raw, uint64(seq.Seq()))

	err = idx.db.Set([]byte(addr), raw)

	if err != nil {
		return errors.Wrap(err, "error in badger transaction (update)")
	}

	idx.l.Lock()
	defer idx.l.Unlock()

	idx.curSeq = seq

	return nil
}

func (idx *index) GetSeq() (margaret.Seq, error) {
	var addr = "__current_observable"

	idx.l.Lock()
	defer idx.l.Unlock()

	if idx.curSeq.Seq() != -2 {
		return idx.curSeq, nil
	}

	data, err := idx.db.Get(nil, []byte(addr))
	if err != nil {
		return margaret.BaseSeq(-2), errors.Wrap(err, "error getting item")
	}
	if data == nil {
		return margaret.SeqEmpty, nil
	}

	if l := len(data); l != 8 {
		return margaret.BaseSeq(-2), errors.Errorf("expected data of length 8, got %v", l)
	}

	idx.curSeq = margaret.BaseSeq(binary.BigEndian.Uint64(data))

	return idx.curSeq, nil
}

type roObv struct {
	luigi.Observable
}

func (obv roObv) Set(interface{}) error {
	return errors.New("read-only observable")
}
