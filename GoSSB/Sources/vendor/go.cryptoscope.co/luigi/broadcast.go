// SPDX-License-Identifier: MIT

package luigi // import "go.cryptoscope.co/luigi"

import (
	"context"
	"sync"

	"github.com/hashicorp/go-multierror"
)

// Broadcast is an interface for registering one or more Sinks to recieve
// updates.
type Broadcast interface {
	// Register a Sink for updates to be sent.
	Register(dst Sink) func()
}

// NewBroadcast returns the Sink, to write to the broadcaster, and the new
// broadcast instance.
func NewBroadcast() (Sink, Broadcast) {
	bcst := broadcast{sinks: make(map[*Sink]struct{})}

	return (*broadcastSink)(&bcst), &bcst
}

type broadcast struct {
	sync.Mutex
	sinks map[*Sink]struct{}
}

// Register implements the Broadcast interface.
func (bcst *broadcast) Register(sink Sink) func() {
	bcst.Lock()
	defer bcst.Unlock()
	bcst.sinks[&sink] = struct{}{}

	return func() {
		bcst.Lock()
		defer bcst.Unlock()
		delete(bcst.sinks, &sink)
		sink.Close()
	}
}

type broadcastSink broadcast

// Pour implements the Sink interface.
func (bcst *broadcastSink) Pour(ctx context.Context, v interface{}) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	bcst.Lock()
	sinks := make([]Sink, 0, len(bcst.sinks))

	for sink := range bcst.sinks {
		sinks = append(sinks, *sink)
	}
	bcst.Unlock()

	for _, s := range sinks {
		err := s.Pour(ctx, v)
		if err != nil {
			return err
		}
	}

	return nil
}

// Close implements the Sink interface.
func (bcst *broadcastSink) Close() error {
	var sinks []Sink

	bcst.Lock()
	defer bcst.Unlock()

	sinks = make([]Sink, 0, len(bcst.sinks))

	for sink := range bcst.sinks {
		sinks = append(sinks, *sink)
	}

	var (
		wg   sync.WaitGroup
		merr *multierror.Error
	)

	wg.Add(len(sinks))
	for _, sink_ := range sinks {
		go func(sink Sink) {
			defer wg.Done()

			err := sink.Close()
			if err != nil {
				merr = multierror.Append(merr, err)
				return
			}
		}(sink_)
	}
	wg.Wait()

	return merr.ErrorOrNil()
}
