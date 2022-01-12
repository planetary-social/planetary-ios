// SPDX-License-Identifier: MIT

package badger // import "go.cryptoscope.co/margaret/multilog/badger"

import (
	"encoding/binary"
	"sync"

	"github.com/dgraph-io/badger"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/luigi"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
)

// New returns a new badger-backed multilog with given codec.
func New(db *badger.DB, codec margaret.Codec) multilog.MultiLog {
	return &mlog{
		db:    db,
		codec: codec,

		sublogs: make(map[librarian.Addr]*sublog),
		curSeq:  margaret.BaseSeq(-2),
	}
}

type mlog struct {
	l sync.Mutex

	db    *badger.DB
	codec margaret.Codec

	sublogs map[librarian.Addr]*sublog
	curSeq  margaret.Seq
}

func (log *mlog) Get(addr librarian.Addr) (margaret.Log, error) {
	shortPrefix := []byte(addr)
	if len(shortPrefix) > 255 {
		return nil, errors.New("supplied address longer than maximum prefix length 255")
	}

	prefix := append([]byte{byte(len(shortPrefix))}, shortPrefix...)

	log.l.Lock()
	defer log.l.Unlock()

	slogAddr := librarian.Addr(prefix)
	slog := log.sublogs[slogAddr]
	if slog != nil {
		if !slog.deleted {
			// sv, _ := slog.Seq().Value()
			// fmt.Fprintf(os.Stderr, "\treturning open and NOT DELETED log. seq %x:\t%v\n", slog.prefix, sv)
			return slog, nil
		}
		// delete(log.sublogs, slogAddr)
	}

	// find the current seq
	var seq margaret.Seq = margaret.SeqEmpty
	err := log.db.View(func(txn *badger.Txn) error {
		iopts := badger.DefaultIteratorOptions
		iopts.Reverse = true

		iter := txn.NewIterator(iopts)
		defer iter.Close()

		iter.Rewind()
		if !iter.Valid() {
			return nil
		}

		// since we're reverse seeking, we need to make sure the seek string is larger
		// than what we look for. Since sequence numbers are actually signed, but we
		// won't store negative ones, we can assume that the first bit is not set,
		// so this is larger than any key that can occur for this prefix.
		iter.Seek(append(prefix, 0x80))
		if !iter.ValidForPrefix(prefix) {
			return nil
		}

		key := iter.Item().Key()
		seqBs := key[len(prefix):]
		if len(seqBs) != 8 {
			return errors.New("invalid key length (expected len(prefix)+8)")
		}
		seq = margaret.BaseSeq(binary.BigEndian.Uint64(seqBs))

		return nil
	})
	if err != nil {
		return nil, errors.Wrap(err, "error in read transaction")
	}
	// fmt.Fprintf(os.Stderr, "\t\tcurrent seq %x:\t%d\n", prefix, seq.Seq())

	slog = &sublog{
		mlog:   log,
		prefix: prefix,
		seq:    luigi.NewObservable(seq),
	}

	log.sublogs[slogAddr] = slog
	return slog, nil
}

func increment(l int, data []byte) {
	if data[l] == 0xff {
		data[l] = 0
		increment(l-1, data)
		return
	}

	data[l]++
}

// List returns a list of all stored sublogs
func (log *mlog) List() ([]librarian.Addr, error) {
	var list []librarian.Addr

	err := log.db.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		var next []byte
		for iter.Rewind(); iter.Valid(); iter.Seek(next) {
			// extract addr from prefix
			key := iter.Item().Key()
			l := key[0] // prefix length
			addr := key[1 : l+1]
			list = append(list, librarian.Addr(addr))

			// increment last byte of prefix to skip all entries with same prefix
			next = key[:l+1]
			increment(int(l), next)
		}

		return nil
	})

	return list, errors.Wrap(err, "badger: error in List() transaction")
}

func (log *mlog) Delete(addr librarian.Addr) error {
	shortPrefix := []byte(addr)
	if len(shortPrefix) > 255 {
		return errors.New("supplied address longer than maximum prefix length 255")
	}

	prefix := append([]byte{byte(len(shortPrefix))}, shortPrefix...)

	log.l.Lock()
	defer log.l.Unlock()

	if sl, ok := log.sublogs[librarian.Addr(prefix)]; ok {
		sl.deleted = true
		sl.seq.Set(multilog.ErrSublogDeleted)
		delete(log.sublogs, librarian.Addr(prefix))
		// fmt.Fprintf(os.Stderr, "deleting sublog %x\n ", addr)
	}

	err := log.db.Update(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		iter.Rewind()
		if !iter.Valid() {
			return nil
		}

		for iter.Seek(prefix); iter.ValidForPrefix(prefix); iter.Next() {
			it := iter.Item()
			key := it.Key()
			// fmt.Fprintf(os.Stderr, "deleting entry %x\n ", key)
			if err := txn.Delete(key); err != nil {
				return errors.Wrapf(err, "failed to delete entry %x", key)
			}
		}

		return nil
	})

	return errors.Wrap(err, "badger: error in Delete() transaction")
}

func (log *mlog) Close() error {
	return log.db.Close()
}

// Flush is a no-op on this implementation.
// should be usefull but all my projects use the roaring bitmap version by now
func (log *mlog) Flush() error { return nil }
