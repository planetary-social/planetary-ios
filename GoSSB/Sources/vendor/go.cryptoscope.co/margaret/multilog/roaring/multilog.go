// SPDX-FileCopyrightText: 2021 The margaret Authors
//
// SPDX-License-Identifier: MIT

package roaring

import (
	"context"
	"errors"
	"fmt"
	stdlog "log"
	"sync"
	"time"

	"github.com/dgraph-io/sroar"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret/indexes"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/internal/persist"
	"go.cryptoscope.co/margaret/internal/seqobsv"
	"go.cryptoscope.co/margaret/multilog"
)

// NewStore returns a new multilog that is only good to store sequences
// It uses files to store roaring bitmaps directly.
// for this it turns the indexes.Addrs into a hex string.
func NewStore(store persist.Saver) *MultiLog {
	ctx, cancel := context.WithCancel(context.TODO())
	ml := &MultiLog{
		store:   store,
		l:       &sync.Mutex{},
		sublogs: make(map[indexes.Addr]*sublog),

		processing:    ctx,
		done:          cancel,
		batcherClosed: make(chan struct{}),
		tickPersist:   time.NewTicker(13 * time.Second),
	}
	go ml.writeBatches()
	return ml
}

func (log *MultiLog) writeBatches() {
	for {
		select {
		case <-log.tickPersist.C:
		case <-log.processing.Done():
			close(log.batcherClosed)
			return
		}
		err := log.Flush()
		if err != nil {
			stdlog.Println("flush trigger failed", err)
		}
	}
}

func (log *MultiLog) Flush() error {
	log.l.Lock()
	defer log.l.Unlock()
	return log.flushAllSublogs()
}

func (log *MultiLog) flushAllSublogs() error {
	var dirtySublogs []persist.KeyValuePair
	for addr, sublog := range log.sublogs {
		if sublog.dirty {
			dirtySublogs = append(dirtySublogs, persist.KeyValuePair{
				Key:   persist.Key(addr),
				Value: sublog.bmap.ToBuffer(),
			})
			sublog.dirty = false
		}
	}

	err := log.store.PutMultiple(dirtySublogs)
	if err != nil {
		return err
	}

	return nil
}

type MultiLog struct {
	store persist.Saver

	l       *sync.Mutex
	sublogs map[indexes.Addr]*sublog

	processing context.Context
	done       context.CancelFunc

	batcherClosed chan struct{}
	tickPersist   *time.Ticker
}

func (log *MultiLog) Get(addr indexes.Addr) (margaret.Log, error) {
	log.l.Lock()
	defer log.l.Unlock()
	return log.openSublog(addr)
}

// openSublog alters the sublogs map, take the lock first!
func (log *MultiLog) openSublog(addr indexes.Addr) (*sublog, error) {
	slog, has := log.sublogs[addr]
	if has {
		return slog, nil
	}

	pk := persist.Key(addr)

	var seq int64

	r, err := log.loadBitmap(pk)
	if errors.Is(err, persist.ErrNotFound) {
		seq = margaret.SeqEmpty
		r = sroar.NewBitmap()
	} else if err != nil {
		return nil, err
	} else {
		seq = int64(r.GetCardinality())
	}

	var obsV uint64
	if seq > 0 {
		obsV = uint64(seq)
	}

	slog = &sublog{
		mlog:      log,
		key:       pk,
		seq:       seqobsv.New(obsV),
		luigiObsv: luigi.NewObservable(seq),
		bmap:      r,
	}
	// the better idea is to have a store that can collece puts
	log.sublogs[addr] = slog
	return slog, nil
}

// LoadInternalBitmap loads the raw roaringbitmap for key
func (log *MultiLog) LoadInternalBitmap(key indexes.Addr) (*sroar.Bitmap, error) {
	if err := log.Flush(); err != nil {
		return nil, err
	}
	bmap, err := log.loadBitmap([]byte(key))
	if err != nil {
		if errors.Is(err, persist.ErrNotFound) {
			return nil, multilog.ErrSublogNotFound
		}
		return nil, err
	}
	return bmap, nil
}

func (log *MultiLog) loadBitmap(key []byte) (*sroar.Bitmap, error) {
	data, err := log.store.Get(key)
	if err != nil {
		return nil, fmt.Errorf("roaringfiles: invalid stored bitfield %s: %w", key, err)
	}

	return sroar.FromBuffer(data), nil
}

func (log *MultiLog) Delete(addr indexes.Addr) error {
	log.l.Lock()
	defer log.l.Unlock()

	if sl, ok := log.sublogs[addr]; ok {
		sl.deleted = true
		sl.luigiObsv.Set(multilog.ErrSublogDeleted)
		sl.seq = seqobsv.New(0)
		delete(log.sublogs, addr)
	}

	return log.store.Delete(persist.Key(addr))
}

// List returns a list of all stored sublogs
func (log *MultiLog) List() ([]indexes.Addr, error) {
	log.l.Lock()
	defer log.l.Unlock()

	err := log.loadAll()
	if err != nil {
		return nil, err
	}

	list := make([]indexes.Addr, len(log.sublogs))
	i := 0
	for addr, sublog := range log.sublogs {
		if sublog.bmap.GetCardinality() == 0 {
			continue
		}
		list[i] = addr
		i++
	}
	list = list[:i] // cut off the skipped ones

	return list, nil
}

func (log *MultiLog) loadAll() error {
	keys, err := log.store.List()
	if err != nil {
		return fmt.Errorf("roaringfiles: store iteration failed: %w", err)
	}
	for _, bk := range keys {
		_, err := log.openSublog(indexes.Addr(bk))
		if err != nil {
			return fmt.Errorf("roaringfiles: broken bitmap file (%s): %w", bk, err)
		}
	}
	return nil
}

func (log *MultiLog) Close() error {
	log.done()
	log.tickPersist.Stop()
	<-log.batcherClosed

	if err := log.Flush(); err != nil {
		return fmt.Errorf("roaringfiles: close failed to flush: %w", err)
	}

	return log.store.Close()
}
