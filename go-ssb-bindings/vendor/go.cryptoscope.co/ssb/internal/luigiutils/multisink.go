// SPDX-License-Identifier: MIT

package luigiutils

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb/internal/neterr"
)

// MultiSink takes each message poured into it, and passes it on to all
// registered sinks.
//
// MultiSink is like luigi.Broadcaster but with context support.
// TODO(cryptix): cool utility! might want to move it to internal until we find  better place
type MultiSink struct {
	seq   int64
	sinks []luigi.Sink
	ctxs  map[luigi.Sink]context.Context
	until map[luigi.Sink]int64

	isClosed bool
}

var _ luigi.Sink = (*MultiSink)(nil)
var _ margaret.Seq = (*MultiSink)(nil)

func NewMultiSink(seq int64) *MultiSink {
	return &MultiSink{
		seq:   seq,
		ctxs:  make(map[luigi.Sink]context.Context),
		until: make(map[luigi.Sink]int64),
	}
}

func (f *MultiSink) Seq() int64 {
	return f.seq
}

// Register adds a sink to propagate messages to upto the 'until'th sequence.
func (f *MultiSink) Register(
	ctx context.Context,
	sink luigi.Sink,
	until int64,
) error {
	f.sinks = append(f.sinks, sink)
	f.ctxs[sink] = ctx
	f.until[sink] = until
	return nil
}

func (f *MultiSink) Unregister(
	sink luigi.Sink,
) error {
	for i, s := range f.sinks {
		if sink != s {
			continue
		}
		f.sinks = append(f.sinks[:i], f.sinks[(i+1):]...)
		delete(f.ctxs, sink)
		delete(f.until, sink)
		return nil
	}
	return nil
}

// Count returns the number of registerd sinks
func (f *MultiSink) Count() uint {
	return uint(len(f.sinks))
}

func (f *MultiSink) Close() error {
	f.isClosed = true
	return nil
}

func (f *MultiSink) Pour(
	_ context.Context,
	msg interface{},
) error {
	if f.isClosed {
		return luigi.EOS{}
	}
	f.seq++

	var deadFeeds []luigi.Sink

	for i, s := range f.sinks {
		err := s.Pour(f.ctxs[s], msg)
		if err != nil {
			causeErr := errors.Cause(err)
			if muxrpc.IsSinkClosed(err) || causeErr == context.Canceled || neterr.IsConnBrokenErr(causeErr) {
				deadFeeds = append(deadFeeds, s)
				continue
			}
			return errors.Wrapf(err, "MultiSink: failed to pour into sink #%d (%v)", i)
		}
		if f.until[s] <= f.seq {
			deadFeeds = append(deadFeeds, s)
		}
	}

	for _, feed := range deadFeeds {
		f.Unregister(feed)
	}

	return nil
}
