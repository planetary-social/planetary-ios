// SPDX-License-Identifier: MIT

package roaring

import (
	"fmt"

	"github.com/dgraph-io/sroar"
	"go.cryptoscope.co/luigi"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/internal/persist"
	"go.cryptoscope.co/margaret/internal/seqobsv"
	"go.cryptoscope.co/margaret/multilog"
)

type sublog struct {
	mlog *MultiLog

	key       persist.Key
	seq       *seqobsv.Observable
	luigiObsv luigi.Observable
	bmap      *sroar.Bitmap

	dirty bool

	deleted bool
}

func (log *sublog) Seq() int64 {
	return log.seq.Seq() - 1
}

func (log *sublog) Changes() luigi.Observable {
	return log.luigiObsv
}

func (log *sublog) Get(seq int64) (interface{}, error) {
	log.mlog.l.Lock()
	defer log.mlog.l.Unlock()
	return log.get(seq)
}

func (log *sublog) get(seq int64) (interface{}, error) {
	if log.deleted {
		return nil, multilog.ErrSublogDeleted
	}

	if seq < 0 {
		return nil, luigi.EOS{}
	}

	v, err := log.bmap.Select(uint64(seq))
	if err != nil {
		return nil, luigi.EOS{}
	}
	return int64(v), err
}

func (log *sublog) Query(specs ...margaret.QuerySpec) (luigi.Source, error) {
	log.mlog.l.Lock()
	defer log.mlog.l.Unlock()
	if log.deleted {
		return nil, multilog.ErrSublogDeleted
	}
	qry := &query{
		log: log,

		lt:      margaret.SeqEmpty,
		nextSeq: margaret.SeqEmpty,

		limit: -1, //i.e. no limit
	}

	for _, spec := range specs {
		err := spec(qry)
		if err != nil {
			return nil, err
		}
	}

	return qry, nil
}

func (log *sublog) Append(v interface{}) (int64, error) {
	log.mlog.l.Lock()
	defer log.mlog.l.Unlock()
	if log.deleted {
		return margaret.SeqSublogDeleted, multilog.ErrSublogDeleted
	}
	val, ok := v.(int64)
	if !ok {
		switch tv := v.(type) {
		case int:
			val = int64(tv)
		case int64:
			val = int64(tv)
		case uint32:
			val = int64(tv)
		default:
			return int64(-2), fmt.Errorf("roaringfiles: not a sequence (%T)", v)
		}
	}
	if val < 0 {
		return margaret.SeqErrored, fmt.Errorf("roaringfiles can only store positive numbers")
	}

	log.bmap.Set(uint64(val))

	log.dirty = true
	log.seq.Inc()

	count := log.bmap.GetCardinality() - 1
	newSeq := int64(count)

	err := log.luigiObsv.Set(newSeq)
	if err != nil {
		err = fmt.Errorf("roaringfiles: failed to update sequence: %w", err)
		return margaret.SeqErrored, err
	}
	return newSeq, nil
}

func (log *sublog) store() error {
	if log.deleted {
		return multilog.ErrSublogDeleted
	}
	data := log.bmap.ToBuffer()

	var err error
	err = log.mlog.store.Put(log.key, data)
	if err != nil {
		return fmt.Errorf("roaringfiles: file write failed: %w", err)
	}
	return nil
}
