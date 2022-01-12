// SPDX-License-Identifier: MIT

package badger // import "go.cryptoscope.co/librarian/badger"

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"log"
	"os"
	"reflect"
	"strconv"
	"sync"
	"time"

	"github.com/dgraph-io/badger"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"

	"go.cryptoscope.co/librarian"
)

// badger starts to complain >100k
var batchFullLimit uint32 = 75000

// NASTY TESTING HACK
func init() {
	limit, has := os.LookupEnv("LIBRARIAN_WRITEALL")
	if has {
		parsed, err := strconv.ParseUint(limit, 10, 32)
		if err != nil {
			panic(err)
		}
		log.Println("[librarian/badger] overwrote batch limit", parsed)
		batchFullLimit = uint32(parsed)
	}
}

type setOp struct {
	addr []byte
	val  []byte
}

type index struct {
	stop    context.CancelFunc
	running context.Context

	l *sync.Mutex

	// these control periodic persistence
	tickPersistAll, tickIfFull *time.Ticker

	batchLowerLimit uint   // only write if there are more batches then this
	batchFullLimit  uint32 // more than this cause an problem in badger

	nextbatch []setOp

	db *badger.DB

	obvs   map[librarian.Addr]luigi.Observable
	tipe   interface{}
	curSeq margaret.BaseSeq
}

func NewIndex(db *badger.DB, tipe interface{}) librarian.SeqSetterIndex {
	ctx, cancel := context.WithCancel(context.TODO())
	idx := &index{
		stop:    cancel,
		running: ctx,

		l: &sync.Mutex{},

		tickPersistAll: time.NewTicker(17 * time.Second),
		tickIfFull:     time.NewTicker(5 * time.Second),

		batchLowerLimit: 32000,
		batchFullLimit:  batchFullLimit,
		nextbatch:       make([]setOp, 0),

		db:     db,
		tipe:   tipe,
		obvs:   make(map[librarian.Addr]luigi.Observable),
		curSeq: margaret.BaseSeq(-2),
	}
	go idx.writeBatches()
	return idx
}

func (idx *index) Flush() error {
	idx.l.Lock()
	defer idx.l.Unlock()

	if err := idx.flushBatch(); err != nil {
		return err
	}
	return nil
}

func (idx *index) Close() error {
	idx.l.Lock()
	defer idx.l.Unlock()

	idx.stop()
	idx.tickIfFull.Stop()
	idx.tickPersistAll.Stop()

	err := idx.flushBatch()
	if err != nil {
		return errors.Wrap(err, "librarian/badger: failed to flush remaining batched operations")
	}
	err = errors.Wrap(idx.db.Close(), "librarian/badger: failed to close backing store")
	return err
}

func (idx *index) flushBatch() error {
	var raw = make([]byte, 8)
	err := idx.db.Update(func(txn *badger.Txn) error {
		useq := uint64(idx.curSeq)
		binary.BigEndian.PutUint64(raw, useq)

		err := txn.Set([]byte("__current_observable"), raw)
		if err != nil {
			return errors.Wrap(err, "error setting seq")
		}

		for bi, op := range idx.nextbatch {
			err := txn.Set(op.addr, op.val)
			if err != nil {
				return errors.Wrapf(err, "error setting batch #%d", bi)
			}
		}
		return nil
	})
	if err != nil {
		return errors.Wrapf(err, "error in badger transaction (update) %d", len(idx.nextbatch))

	}
	idx.nextbatch = []setOp{}
	return nil
}

func (idx *index) writeBatches() {

	for {
		var writeAll = false

		// if this was in the same select with the ticker below,
		// the ticker with the smaller durration would always overrule the longer one
		select {
		case <-idx.tickPersistAll.C:
			writeAll = true
		default:
		}

		select {
		case <-idx.tickIfFull.C:

		case <-idx.running.Done():
			return
		}
		idx.l.Lock()
		n := uint(len(idx.nextbatch))

		if !writeAll {
			if n < idx.batchLowerLimit {
				idx.l.Unlock()
				continue
			}
		}
		if n == 0 {
			idx.l.Unlock()
			continue
		}

		err := idx.flushBatch()
		if err != nil {
			// TODO: maybe set error and stop further writes?
			log.Println("librarian: flushing failed", err)
		}
		idx.l.Unlock()
	}
}

func (idx *index) Get(ctx context.Context, addr librarian.Addr) (luigi.Observable, error) {
	idx.l.Lock()
	defer idx.l.Unlock()

	obv, ok := idx.obvs[addr]
	if ok {
		return obv, nil
	}

	if err := idx.flushBatch(); err != nil {
		return nil, err
	}

	t := reflect.TypeOf(idx.tipe)
	v := reflect.New(t).Interface()

	err := idx.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(addr))
		if err != nil {
			return errors.Wrap(err, "error getting item")
		}

		err = item.Value(func(data []byte) error {
			if um, ok := v.(librarian.Unmarshaler); ok {
				if t.Kind() != reflect.Ptr {
					v = reflect.ValueOf(v).Elem().Interface()
				}

				err = um.Unmarshal(data)
				return errors.Wrap(err, "error unmarshaling using custom marshaler")
			}

			err = json.Unmarshal(data, v)
			if err != nil {
				return errors.Wrap(err, "error unmarshaling using json marshaler")
			}

			if t.Kind() != reflect.Ptr {
				v = reflect.ValueOf(v).Elem().Interface()
			}
			return nil
		})
		if err != nil {
			return errors.Wrap(err, "error getting value")
		}

		return err
	})

	if err != nil && errors.Cause(err) != badger.ErrKeyNotFound {
		return nil, errors.Wrap(err, "error in badger transaction (view)")
	}

	if errors.Cause(err) == badger.ErrKeyNotFound {
		obv = librarian.NewObservable(librarian.UnsetValue{Addr: addr}, idx.deleter(addr))
	} else {
		obv = librarian.NewObservable(v, idx.deleter(addr))
	}

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

	idx.l.Lock()
	defer idx.l.Unlock()
	batchedOp := setOp{
		addr: []byte(addr),
		val:  raw,
	}
	idx.nextbatch = append(idx.nextbatch, batchedOp)

	if n := uint32(len(idx.nextbatch)); n > idx.batchFullLimit {
		err = idx.flushBatch()
		if err != nil {
			return errors.Wrapf(err, "failed to write big batch (%d)", n)
		}
	}

	obv, ok := idx.obvs[addr]
	if ok {
		err = obv.Set(v)
		err = errors.Wrap(err, "error setting value in observable")
	}

	return err
}

func (idx *index) Delete(ctx context.Context, addr librarian.Addr) error {
	err := idx.db.Update(func(txn *badger.Txn) error {
		err := txn.Delete([]byte(addr))
		return errors.Wrap(err, "error deleting item")
	})
	if err != nil {
		return errors.Wrap(err, "error in badger transaction (update)")
	}

	idx.l.Lock()
	defer idx.l.Unlock()

	obv, ok := idx.obvs[addr]
	if ok {
		err = obv.Set(librarian.UnsetValue{Addr: addr})
		err = errors.Wrap(err, "error setting value in observable")
	}

	return err
}

func (idx *index) SetSeq(seq margaret.Seq) error {
	idx.l.Lock()
	defer idx.l.Unlock()

	idx.curSeq = margaret.BaseSeq(seq.Seq())
	return nil
}

func (idx *index) GetSeq() (margaret.Seq, error) {
	var addr = "__current_observable"

	idx.l.Lock()
	defer idx.l.Unlock()

	if idx.curSeq.Seq() != -2 {
		return idx.curSeq, nil
	}

	err := idx.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(addr))
		if err != nil {
			return errors.Wrap(err, "error getting item")
		}

		err = item.Value(func(data []byte) error {

			if l := len(data); l != 8 {
				return errors.Errorf("expected data of length 8, got %v", l)
			}

			idx.curSeq = margaret.BaseSeq(binary.BigEndian.Uint64(data))

			return nil
		})
		if err != nil {
			return errors.Wrap(err, "error getting value")
		}

		return nil
	})

	if err != nil {
		if errors.Cause(err) == badger.ErrKeyNotFound {
			return margaret.SeqEmpty, nil
		}
		return margaret.BaseSeq(0), errors.Wrap(err, "error in badger transaction (view)")
	}

	return idx.curSeq, nil
}

type roObv struct {
	luigi.Observable
}

func (obv roObv) Set(interface{}) error {
	return errors.New("read-only observable")
}
