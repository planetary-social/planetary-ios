// SPDX-License-Identifier: MIT

package roaring

import (
	"github.com/RoaringBitmap/roaring"
	"github.com/pkg/errors"
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
	bmap      *roaring.Bitmap

	dirty bool

	deleted bool
}

func (log *sublog) Seq() luigi.Observable {
	return log.luigiObsv
}

func (log *sublog) Get(seq margaret.Seq) (interface{}, error) {
	log.mlog.l.Lock()
	defer log.mlog.l.Unlock()
	return log.get(seq)
}

func (log *sublog) get(seq margaret.Seq) (interface{}, error) {
	if log.deleted {
		return nil, multilog.ErrSublogDeleted
	}

	if seq.Seq() < 0 {
		return nil, luigi.EOS{}
	}

	v, err := log.bmap.Select(uint32(seq.Seq()))
	if err != nil {
		return nil, luigi.EOS{}
	}
	return margaret.BaseSeq(v), err
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

func (log *sublog) Append(v interface{}) (margaret.Seq, error) {
	log.mlog.l.Lock()
	defer log.mlog.l.Unlock()
	if log.deleted {
		return nil, multilog.ErrSublogDeleted
	}
	val, ok := v.(margaret.BaseSeq)
	if !ok {
		switch tv := v.(type) {
		case int:
			val = margaret.BaseSeq(tv)
		case int64:
			val = margaret.BaseSeq(tv)
		case uint32:
			val = margaret.BaseSeq(tv)
		default:
			return margaret.BaseSeq(-2), errors.Errorf("roaringfiles: not a sequence (%T)", v)
		}
	}
	if val.Seq() < 0 {
		return nil, errors.Errorf("roaringfiles can only store positive numbers")
	}

	log.bmap.Add(uint32(val.Seq()))

	log.dirty = true
	log.seq.Inc()

	count := log.bmap.GetCardinality() - 1
	newSeq := margaret.BaseSeq(count)

	err := log.luigiObsv.Set(newSeq)
	if err != nil {
		err = errors.Wrap(err, "roaringfiles: failed to update sequence")
		return margaret.BaseSeq(-2), err
	}
	return newSeq, nil
}

func (log *sublog) store() error {
	data, err := log.bmap.MarshalBinary()
	if err != nil {
		return errors.Wrap(err, "roaringfiles: failed to encode bitmap")
	}

	err = log.mlog.store.Put(log.key, data)
	if err != nil {
		return errors.Wrap(err, "roaringfiles: file write failed")
	}
	return nil
}
