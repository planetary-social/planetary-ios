// SPDX-License-Identifier: MIT

package luigiutils

import (
	"context"
	"sync"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
)

// MultiSink takes each message poured into it, and passes it on to all
// registered sinks.
//
// MultiSink is like luigi.Broadcaster but with context support.
type MultiSink struct {
	seq      int64
	isClosed bool

	mu    sync.Mutex
	sinks mapOfSinks
}

type mapOfSinks map[*muxrpc.ByteSink]sinkContext

type sinkContext struct {
	ctx   context.Context
	until int64
}

var _ margaret.Seqer = (*MultiSink)(nil)

func NewMultiSink(seq int64) *MultiSink {
	return &MultiSink{
		seq:   seq,
		sinks: make(mapOfSinks),
	}
}

func (f *MultiSink) Seq() int64 {
	return int64(f.seq)
}

// Register adds a sink to propagate messages to upto the 'until'th sequence.
func (f *MultiSink) Register(
	ctx context.Context,
	sink *muxrpc.ByteSink,
	until int64,
) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sinks[sink] = sinkContext{
		ctx:   ctx,
		until: until,
	}
}

func (f *MultiSink) Unregister(
	sink *muxrpc.ByteSink,
) {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.sinks, sink)
}

// Count returns the number of registerd sinks
func (f *MultiSink) Count() uint {
	f.mu.Lock()
	defer f.mu.Unlock()
	return uint(len(f.sinks))
}

func (f *MultiSink) Close() error {
	f.isClosed = true
	return nil
}

func (f *MultiSink) Send(msg []byte) {
	if f.isClosed {
		return
	}
	f.seq++

	f.mu.Lock()
	defer f.mu.Unlock()

	for s, ctx := range f.sinks {
		_, err := s.Write(msg)
		if err != nil || ctx.until <= f.seq {
			delete(f.sinks, s)
		}

	}
}
