// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package broadcasts

import (
	"sync"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/multierror"
)

// NewBlobStoreEmitter returns the Sink, to write to the broadcaster, and the new
// broadcast instance.
func NewBlobStoreEmitter() (ssb.BlobStoreEmitter, *BlobStoreBroadcast) {
	bcst := BlobStoreBroadcast{
		mu:    &sync.Mutex{},
		sinks: make(map[*ssb.BlobStoreEmitter]struct{}),
	}

	return (*BlobStoreSink)(&bcst), &bcst
}

// BlobStoreBroadcast is an interface for registering one or more Sinks to recieve
// updates.
type BlobStoreBroadcast struct {
	mu    *sync.Mutex
	sinks map[*ssb.BlobStoreEmitter]struct{}
}

// Register a Sink for updates to be sent. also returns
func (bcst *BlobStoreBroadcast) Register(sink ssb.BlobStoreEmitter) ssb.CancelFunc {
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

type BlobStoreSink BlobStoreBroadcast

// Pour implements the Sink interface.
func (bcst *BlobStoreSink) EmitBlob(nf ssb.BlobStoreNotification) error {

	bcst.mu.Lock()
	for s := range bcst.sinks {
		err := (*s).EmitBlob(nf)
		if err != nil {
			delete(bcst.sinks, s)
		}
	}
	bcst.mu.Unlock()

	return nil
}

// Close implements the Sink interface.
func (bcst *BlobStoreSink) Close() error {
	var sinks []ssb.BlobStoreEmitter

	bcst.mu.Lock()
	defer bcst.mu.Unlock()

	sinks = make([]ssb.BlobStoreEmitter, 0, len(bcst.sinks))

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
		go func(sink ssb.BlobStoreEmitter) {
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

// util
type BlobStoreFuncEmitter func(not ssb.BlobStoreNotification) error

func (e BlobStoreFuncEmitter) EmitBlob(not ssb.BlobStoreNotification) error {
	return e(not)
}

func (e BlobStoreFuncEmitter) Close() error {
	return nil
}
