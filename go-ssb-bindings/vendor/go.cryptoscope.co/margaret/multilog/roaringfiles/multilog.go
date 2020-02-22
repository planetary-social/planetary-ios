// SPDX-License-Identifier: MIT

package roaringfiles

import (
	"fmt"
	"sync"

	"github.com/dustin/go-humanize"

	"github.com/RoaringBitmap/roaring"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/luigi"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/internal/persist"
	"go.cryptoscope.co/margaret/internal/persist/fs"
	"go.cryptoscope.co/margaret/internal/persist/mkv"
	"go.cryptoscope.co/margaret/internal/persist/sqlite"
	"go.cryptoscope.co/margaret/internal/seqobsv"
	"go.cryptoscope.co/margaret/multilog"
)

// New returns a new multilog that is only good to store sequences
// It uses files to store roaring bitmaps directly.
// for this it turns the librarian.Addrs into a hex string.

func NewFS(base string) *MultiLog {
	return newAbstract(fs.New(base))
}

func NewSQLite(base string) (*MultiLog, error) {
	s, err := sqlite.New(base)
	if err != nil {
		return nil, err
	}
	return newAbstract(s), nil
}

func NewMKV(base string) (*MultiLog, error) {
	s, err := mkv.New(base)
	if err != nil {
		return nil, err
	}
	return newAbstract(s), nil
}

func newAbstract(store persist.Saver) *MultiLog {
	return &MultiLog{
		store:   store,
		sublogs: make(map[librarian.Addr]*sublog),
		curSeq:  margaret.BaseSeq(-2),
	}
}

type MultiLog struct {
	store persist.Saver

	curSeq margaret.Seq

	l       sync.Mutex
	sublogs map[librarian.Addr]*sublog
}

func (log *MultiLog) Get(addr librarian.Addr) (margaret.Log, error) {
	log.l.Lock()
	defer log.l.Unlock()
	return log.openSublog(addr)
}

// openSublog alters the sublogs map, take the lock first!
func (log *MultiLog) openSublog(addr librarian.Addr) (*sublog, error) {
	slog := log.sublogs[addr]
	if slog != nil {
		return slog, nil
	}

	pk := persist.Key(addr)

	var seq margaret.BaseSeq

	r, err := log.loadBitmap(pk)
	if errors.Cause(err) == persist.ErrNotFound {
		seq = margaret.SeqEmpty
		r = roaring.New()
	} else if err != nil {
		return nil, err
	} else {
		seq = margaret.BaseSeq(r.GetCardinality() - 1)
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

func (log *MultiLog) loadBitmap(key []byte) (*roaring.Bitmap, error) {
	var r *roaring.Bitmap

	data, err := log.store.Get(key)
	if err != nil {
		return nil, errors.Wrapf(err, "roaringfiles: invalid stored bitfield %x", key)
	}

	r = roaring.New()
	err = r.UnmarshalBinary(data)
	if err != nil {
		return nil, errors.Wrapf(err, "roaringfiles: unpack of %x failed", key)
	}

	return r, nil
}

func (log *MultiLog) compress(key persist.Key, r *roaring.Bitmap) (bool, error) {
	n := r.GetSizeInBytes()
	if n < 4*1024 {
		return false, nil
	}

	currSize := r.GetSerializedSizeInBytes()
	r.RunOptimize()
	newSize := r.GetSerializedSizeInBytes()

	if currSize < newSize {
		return false, nil
	}

	compressed, err := r.MarshalBinary()
	if err != nil {
		return false, errors.Wrap(err, "roaringfiles: compress marshal failed")
	}
	err = log.store.Put(key, compressed)
	if err != nil {
		return false, errors.Wrap(err, "roaringfiles: write compressed failed")
	}
	fmt.Printf("roaringfiles/compress(%s): reduced to %s (%d entries)\n", key, humanize.Bytes(newSize), n)
	return true, nil
}

func (log *MultiLog) CompressAll() error {
	log.l.Lock()
	defer log.l.Unlock()

	// save open ones
	for addr, sublog := range log.sublogs {
		_, err := sublog.update()
		if err != nil {
			return errors.Wrapf(err, "failed to update open sublog %x", addr)
		}
	}
	// load idle ones
	err := log.loadAll()
	if err != nil {
		return errors.Wrap(err, "failed to load all sublogs")
	}

	// compress all
	for addr, sublog := range log.sublogs {
		_, err := log.compress(persist.Key(addr), sublog.bmap)
		if err != nil {
			return errors.Wrapf(err, "failed to update open sublog %x", addr)
		}
	}
	return nil
}

func (log *MultiLog) Delete(addr librarian.Addr) error {
	log.l.Lock()
	defer log.l.Unlock()

	if sl, ok := log.sublogs[addr]; ok {
		sl.deleted = true
		sl.luigiObsv.Set(multilog.ErrSublogDeleted)
		delete(log.sublogs, addr)
	}

	return log.store.Delete(persist.Key(addr))
}

// List returns a list of all stored sublogs
func (log *MultiLog) List() ([]librarian.Addr, error) {
	log.l.Lock()
	defer log.l.Unlock()

	err := log.loadAll()
	if err != nil {
		return nil, err
	}

	list := make([]librarian.Addr, len(log.sublogs))
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
		return errors.Wrap(err, "roaringfiles: store iteration failed")
	}
	for _, bk := range keys {
		_, err := log.openSublog(librarian.Addr(bk))
		if err != nil {
			return errors.Wrapf(err, "roaringfiles: broken bitmap file (%s)", bk)
		}
	}
	return nil
}

func (log *MultiLog) Close() error {
	return log.store.Close()
}
