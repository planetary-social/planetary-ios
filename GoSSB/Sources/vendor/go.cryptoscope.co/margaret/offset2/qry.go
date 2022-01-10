// SPDX-License-Identifier: MIT

package offset2 // import "go.cryptoscope.co/margaret/offset2"

import (
	"context"
	stderrs "errors"
	"fmt"
	"io"
	"os"
	"sync"
	"syscall"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"

	"github.com/pkg/errors"
)

type offsetQuery struct {
	l     sync.Mutex
	log   *offsetLog
	codec margaret.Codec

	nextSeq, lt margaret.BaseSeq

	limit   int
	live    bool
	seqWrap bool
	reverse bool
	close   chan struct{}
	err     error
}

func (qry *offsetQuery) Gt(s margaret.Seq) error {
	if qry.nextSeq > margaret.SeqEmpty {
		return errors.Errorf("lower bound already set")
	}

	qry.nextSeq = margaret.BaseSeq(s.Seq() + 1)
	return nil
}

func (qry *offsetQuery) Gte(s margaret.Seq) error {
	if qry.nextSeq > margaret.SeqEmpty {
		return errors.Errorf("lower bound already set")
	}

	qry.nextSeq = margaret.BaseSeq(s.Seq())
	return nil
}

func (qry *offsetQuery) Lt(s margaret.Seq) error {
	if qry.lt != margaret.SeqEmpty {
		return errors.Errorf("upper bound already set")
	}

	qry.lt = margaret.BaseSeq(s.Seq())
	return nil
}

func (qry *offsetQuery) Lte(s margaret.Seq) error {
	if qry.lt != margaret.SeqEmpty {
		return errors.Errorf("upper bound already set")
	}

	qry.lt = margaret.BaseSeq(s.Seq() + 1)
	return nil
}

func (qry *offsetQuery) Limit(n int) error {
	qry.limit = n
	return nil
}

func (qry *offsetQuery) Live(live bool) error {
	qry.live = live
	return nil
}

func (qry *offsetQuery) SeqWrap(wrap bool) error {
	qry.seqWrap = wrap
	return nil
}

func (qry *offsetQuery) Reverse(yes bool) error {
	qry.reverse = yes
	if yes {
		if err := qry.setCursorToLast(); err != nil {
			return err
		}
	}
	return nil
}

func (qry *offsetQuery) setCursorToLast() error {
	v, err := qry.log.seq.Value()
	if err != nil {
		return errors.Wrap(err, "setCursorToLast: failed to establish current value")
	}
	currSeq, ok := v.(margaret.Seq)
	if !ok {
		return errors.Errorf("setCursorToLast: failed to establish current value")
	}
	qry.nextSeq = margaret.BaseSeq(currSeq.Seq())
	return nil
}

func (qry *offsetQuery) Next(ctx context.Context) (interface{}, error) {
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

	qry.log.l.Lock()
	defer qry.log.l.Unlock()

	if qry.lt != margaret.SeqEmpty && !(qry.nextSeq < qry.lt) {
		return nil, luigi.EOS{}
	}

	v, err := qry.log.readFrame(qry.nextSeq)
	if errors.Cause(err) == io.EOF {
		if !qry.live {
			return nil, luigi.EOS{}
		}

		wait := make(chan struct{})
		var cancel func()
		cancel = qry.log.seq.Register(luigi.FuncSink(
			func(ctx context.Context, v interface{}, err error) error {
				if err != nil {
					return err
				}
				if v.(margaret.Seq).Seq() >= qry.nextSeq.Seq() {
					close(wait)
					cancel()
				}

				return nil
			}))

		err = func() error {
			qry.log.l.Unlock()
			defer qry.log.l.Lock()

			select {
			case <-wait:
			case <-ctx.Done():
				return ctx.Err()
			}
			return nil
		}()
		if err != nil {
			return nil, err
		}
	} else if errors.Cause(err) == margaret.ErrNulled {
		// TODO: qry.skipNulled
		qry.nextSeq++
		return margaret.ErrNulled, nil
	} else if err != nil {
		return nil, err
	}

	// we waited until the value is in the log - now read it again

	v, err = qry.log.readFrame(qry.nextSeq)
	if errors.Cause(err) == io.EOF {
		return nil, io.ErrUnexpectedEOF
	} else if err != nil {
		return nil, err
	}

	defer func() {
		if qry.reverse {
			qry.nextSeq--
		} else {
			qry.nextSeq++
		}
	}()

	if qry.seqWrap {
		return margaret.WrapWithSeq(v, qry.nextSeq), nil
	}

	return v, nil
}

func (qry *offsetQuery) Push(ctx context.Context, sink luigi.Sink) error {
	// first fast fwd's until we are up to date,
	// then hooks us into the live log updater.
	cancel, err := qry.fastFwdPush(ctx, sink)
	if err != nil {
		return errors.Wrap(err, "error in fast forward")
	}

	defer cancel()

	// block until cancelled, then clean up and return
	select {
	case <-ctx.Done():
		if qry.err != nil {
			return qry.err
		}

		return ctx.Err()
	case <-qry.close:
		return qry.err
	}
}

func (qry *offsetQuery) fastFwdPush(ctx context.Context, sink luigi.Sink) (func(), error) {
	qry.log.l.Lock()
	defer qry.log.l.Unlock()

	if qry.nextSeq == margaret.SeqEmpty {
		if qry.reverse {
			// reset since log is updated since the query was created
			if err := qry.setCursorToLast(); err != nil {
				return nil, err
			}
		} else {
			qry.nextSeq = 0
		}
	}

	// determines whether we should go on
	hasNext := func(seq margaret.BaseSeq) bool {
		return qry.limit != 0 && !(qry.lt >= 0 && seq >= qry.lt)
	}

	for hasNext(qry.nextSeq) {
		qry.limit--

		// TODO: maybe don't read the frames individually but stream over them?
		//     i.e. don't use ReadAt but have a separate fd just for this query
		//     and just Read that.
		v, err := qry.log.readFrame(qry.nextSeq)
		if errors.Cause(err) == margaret.ErrNulled {
			// TODO: if qry.skipNulls
			v = margaret.ErrNulled
		} else if err != nil {
			cerr := errors.Cause(err)
			if cerr != io.EOF {
				var perr *os.PathError
				if stderrs.As(cerr, &perr) {
					if perr.Op == "seek" && (stderrs.Is(perr.Err, syscall.EINVAL) || stderrs.Is(perr.Err, os.ErrInvalid)) {
						// seeked passed the end == EOF
						break
					}
				}
				return func() {}, err
			}
			break
		}

		if qry.seqWrap {
			v = margaret.WrapWithSeq(v, qry.nextSeq)
		}
		err = sink.Pour(ctx, v)
		if err != nil {
			return nil, errors.Wrapf(err, "error pouring read value of seq:%d", qry.nextSeq)
		}

		if qry.reverse {
			qry.nextSeq--
		} else {
			qry.nextSeq++
		}
	}

	if !hasNext(qry.nextSeq) {
		close(qry.close)
		return func() {}, nil
	}

	if !qry.live {
		close(qry.close)
		return func() {}, nil
	}

	var cancel func()
	var closed bool
	cancel = qry.log.bcast.Register(LockSink(luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			if closed {
				return errors.New("closing closed sink")
			}

			closed = true
			select {
			case <-qry.close:
			default:
				close(qry.close)
			}

			return nil
		}

		sw := v.(margaret.SeqWrapper)
		v, seq := sw.Value(), sw.Seq()

		if !hasNext(margaret.BaseSeq(seq.Seq())) {
			close(qry.close)
		}

		if qry.seqWrap {
			v = sw
		}

		return errors.Wrap(sink.Pour(ctx, v), "offset2/push qry: pour of next live value failed")
	})))

	return cancel, nil
}

func LockSink(sink luigi.Sink) luigi.Sink {
	var l sync.Mutex

	return luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		l.Lock()
		defer l.Unlock()

		if err != nil {
			cwe, ok := sink.(interface{ CloseWithError(error) error })
			if ok {
				return cwe.CloseWithError(err)
			}

			if err != (luigi.EOS{}) {
				fmt.Printf("was closed with error %q but underlying sink can not be closed with error\n", err)
			}

			return sink.Close()
		}

		return sink.Pour(ctx, v)
	})
}
