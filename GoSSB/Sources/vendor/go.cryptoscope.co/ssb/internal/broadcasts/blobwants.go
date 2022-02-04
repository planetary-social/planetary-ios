// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package broadcasts

import (
	"sync"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/multierror"
)

// NewBlobWantsEmitter returns the Sink, to write to the broadcaster, and the new
// broadcast instance.
func NewBlobWantsEmitter() (ssb.BlobWantsEmitter, *BlobWantsBroadcast) {
	bcst := BlobWantsBroadcast{
		mu:    &sync.Mutex{},
		sinks: make(map[*ssb.BlobWantsEmitter]struct{}),
	}

	return (*BlobWantsSink)(&bcst), &bcst
}

// BlobWantsBroadcast is an interface for registering one or more Sinks to recieve
// updates.
type BlobWantsBroadcast struct {
	mu    *sync.Mutex
	sinks map[*ssb.BlobWantsEmitter]struct{}
}

// Register a Sink for updates to be sent. also returns
func (bcst *BlobWantsBroadcast) Register(sink ssb.BlobWantsEmitter) ssb.CancelFunc {
	bcst.mu.Lock()
	defer bcst.mu.Unlock()
	bcst.sinks[&sink] = struct{}{}

	return func() {
		bcst.mu.Lock()
		defer bcst.mu.Unlock()
		delete(bcst.sinks, &sink)
		sink.Close()
	}
}

type BlobWantsSink BlobWantsBroadcast

// Pour implements the Sink interface.
func (bcst *BlobWantsSink) EmitWant(w ssb.BlobWant) error {

	bcst.mu.Lock()
	for s := range bcst.sinks {
		err := (*s).EmitWant(w)
		if err != nil {
			delete(bcst.sinks, s)
		}
	}
	bcst.mu.Unlock()

	return nil
}

// Close implements the Sink interface.
func (bcst *BlobWantsSink) Close() error {
	var sinks []ssb.BlobWantsEmitter

	bcst.mu.Lock()
	defer bcst.mu.Unlock()

	sinks = make([]ssb.BlobWantsEmitter, 0, len(bcst.sinks))

	for sink := range bcst.sinks {
		sinks = append(sinks, *sink)
	}

	var (
		wg sync.WaitGroup
		me multierror.List
	)

	// might be fine without the waitgroup and concurrency

	wg.Add(len(sinks))
	for _, sink_ := range sinks {
		go func(sink ssb.BlobWantsEmitter) {
			defer wg.Done()

			err := sink.Close()
			if err != nil {
				me.Errs = append(me.Errs, err)
				return
			}
		}(sink_)
	}
	wg.Wait()

	if len(me.Errs) == 0 {
		return nil
	}

	return me
}
