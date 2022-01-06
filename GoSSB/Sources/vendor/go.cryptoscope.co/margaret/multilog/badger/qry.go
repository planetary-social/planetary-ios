// SPDX-License-Identifier: MIT

package badger

import (
	"context"
	"encoding/binary"
	"sync"

	"github.com/dgraph-io/badger"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
)

type query struct {
	l   sync.Mutex
	log *sublog

	nextSeq, lt margaret.BaseSeq

	limit   int
	reverse bool
	live    bool
	seqWrap bool
}

func (qry *query) Gt(s margaret.Seq) error {
	if qry.nextSeq > margaret.SeqEmpty {
		return errors.Errorf("lower bound already set")
	}

	qry.nextSeq = margaret.BaseSeq(s.Seq() + 1)
	return nil
}

func (qry *query) Gte(s margaret.Seq) error {
	if qry.nextSeq > margaret.SeqEmpty {
		return errors.Errorf("lower bound already set")
	}

	qry.nextSeq = margaret.BaseSeq(s.Seq())
	return nil
}

func (qry *query) Lt(s margaret.Seq) error {
	if qry.lt != margaret.SeqEmpty {
		return errors.Errorf("upper bound already set")
	}

	qry.lt = margaret.BaseSeq(s.Seq())
	return nil
}

func (qry *query) Lte(s margaret.Seq) error {
	if qry.lt != margaret.SeqEmpty {
		return errors.Errorf("upper bound already set")
	}

	qry.lt = margaret.BaseSeq(s.Seq() + 1)
	return nil
}

func (qry *query) Reverse(yes bool) error {
	qry.reverse = yes
	if yes {
		v, err := qry.log.seq.Value()
		if err != nil {
			return errors.Wrap(err, "offsetQry: failed to establish current value")
		}

		currSeq, ok := v.(margaret.Seq)
		if !ok {
			return errors.Errorf("offsetQry: failed to establish current value")
		}
		qry.nextSeq = margaret.BaseSeq(currSeq.Seq())
	}
	return nil
}

func (qry *query) Limit(n int) error {
	qry.limit = n
	return nil
}

func (qry *query) Live(live bool) error {
	qry.live = live
	return nil
}

func (qry *query) SeqWrap(wrap bool) error {
	qry.seqWrap = wrap
	return nil
}

func (qry *query) Next(ctx context.Context) (interface{}, error) {
	qry.l.Lock()
	defer qry.l.Unlock()

	if qry.limit == 0 {
		return nil, luigi.EOS{}
	}
	qry.limit--

	if qry.nextSeq == margaret.SeqEmpty {
		if qry.reverse {
			return nil, luigi.EOS{}
		}
		qry.nextSeq = 0
	}

	if qry.lt != margaret.SeqEmpty {
		if qry.nextSeq >= qry.lt {
			return nil, luigi.EOS{}
		}
	}

	// TODO: use iterator instead of getting sequentially

	nextSeqBs := make([]byte, 8)
	binary.BigEndian.PutUint64(nextSeqBs, uint64(qry.nextSeq))
	prefix := make([]byte, len(qry.log.prefix))
	copy(prefix, qry.log.prefix)
	key := append(prefix, nextSeqBs...)

	var v interface{}

	err := qry.log.mlog.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get(key)
		if err != nil {
			return errors.Wrap(err, "error getting item")
		}

		err = item.Value(func(data []byte) error {
			v, err = qry.log.mlog.codec.Unmarshal(data)
			return err
		})
		if err != nil {
			return errors.Wrap(err, "error getting value")
		}

		return nil
	})
	if err != nil {
		if errors.Cause(err) != badger.ErrKeyNotFound {
			return nil, errors.Wrap(err, "error in read transaction")
		}

		// key not found, so we reached the end
		// abort if not a live query, else wait until it's written
		if !qry.live {
			return nil, luigi.EOS{}
		}

		return qry.livequery(ctx)
	}

	if qry.seqWrap {
		v = margaret.WrapWithSeq(v, qry.nextSeq)
		if qry.reverse {
			qry.nextSeq--
		} else {
			qry.nextSeq++
		}
		return v, nil
	}

	if qry.reverse {
		qry.nextSeq--
	} else {
		qry.nextSeq++
	}
	return v, nil
}

func (qry *query) livequery(ctx context.Context) (interface{}, error) {
	wait := make(chan margaret.Seq)
	closed := make(chan struct{})

	currNextSeq := qry.nextSeq.Seq()

	// register waiter for new messages
	cancel := qry.log.seq.Register(luigi.FuncSink(
		func(ctx context.Context, v interface{}, err error) error {
			if err != nil {
				close(closed)
				return nil
			}

			seqV, ok := v.(margaret.Seq)
			if !ok {
				return errors.Errorf("lievquery: expected sequence value from observable")
			}

			if seqV.Seq() == currNextSeq {
				wait <- seqV
			}

			return nil
		}))

	var (
		v   interface{}
		err error
	)

	select {
	case newSeq := <-wait:
		v, err = qry.log.Get(newSeq)
		if !qry.seqWrap { // simpler to have two +1's here then a defer
			qry.nextSeq++
		}
	case <-closed:
		err = errors.New("seq observable closed")
	case <-ctx.Done():
		err = errors.Wrap(ctx.Err(), "cancelled while waiting for value to be written")
	}

	cancel()

	if err != nil {
		return nil, errors.Wrap(err, "livequery failed to retreive value")
	}

	if qry.seqWrap {
		v = margaret.WrapWithSeq(v, qry.nextSeq)
		qry.nextSeq++
		return v, nil
	}

	return v, nil
}
