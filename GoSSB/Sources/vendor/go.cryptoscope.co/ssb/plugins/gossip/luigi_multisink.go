// SPDX-License-Identifier: MIT

package gossip

import (
	"context"
	"github.com/pkg/errors"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
)

// multiSink takes each message poured into it, and passes it on to all
// registered sinks.
//
// multiSink is like luigi.Broadcaster but with context support.
// TODO(cryptix): cool utility! might want to move it to internal until we find  better place
type multiSink struct {
	seq   int64
	sinks []luigi.Sink
	ctxs  map[luigi.Sink]context.Context
	until map[luigi.Sink]int64

	isClosed bool
}

var _ luigi.Sink = (*multiSink)(nil)
var _ margaret.Seq = (*multiSink)(nil)

func newMultiSink(seq int64) *multiSink {
	return &multiSink{
		seq:   seq,
		ctxs:  make(map[luigi.Sink]context.Context),
		until: make(map[luigi.Sink]int64),
	}
}

func (f *multiSink) Seq() int64 {
	return f.seq
}

// Register adds a sink to propagate messages to upto the 'until'th sequence.
func (f *multiSink) Register(
	ctx context.Context,
	sink luigi.Sink,
	until int64,
) error {
	f.sinks = append(f.sinks, sink)
	f.ctxs[sink] = ctx
	f.until[sink] = until
	return nil
}

func (f *multiSink) Unregister(
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

func (f *multiSink) Close() error {
	f.isClosed = true
	return nil
}

func (f *multiSink) Pour(
	ctx context.Context,
	msg interface{},
) error {
	if f.isClosed {
		return luigi.EOS{}
	}
	f.seq++

	var deadFeeds []luigi.Sink

	for i, s := range f.sinks {
		err := s.Pour(f.ctxs[s], msg)
		if luigi.IsEOS(err) || muxrpc.IsSinkClosed(err) || f.until[s] <= f.seq {
			deadFeeds = append(deadFeeds, s)
			continue
		} else if err != nil {
			// QUESTION: should CloseWithError be used here?
			err := errors.Wrapf(err, "multiSink: failed to pour into sink #%d (%v)", i, f.until[s] <= f.seq)
			return err
		}
	}

	for _, feed := range deadFeeds {
		f.Unregister(feed)
	}

	return nil
}
