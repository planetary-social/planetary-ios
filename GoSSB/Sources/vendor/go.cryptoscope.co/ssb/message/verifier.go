// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package message

import (
	"fmt"
	"sync"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	refs "go.mindeco.de/ssb-refs"
)

// NewVerificationRouter supplies a unique drain per author that skip duplicate messages
func NewVerificationRouter(rxlog margaret.Log, feeds multilog.MultiLog, hmacSec *[32]byte) (*VerificationRouter, error) {
	return &VerificationRouter{
		hmacSec: hmacSec,

		rxlog: rxlog,
		feeds: feeds,
		saver: MargaretSaver{rxlog},

		mu:    new(sync.Mutex),
		sinks: make(verifyFanIn),
	}, nil
}

type MargaretSaver struct {
	margaret.Log
}

func (ms MargaretSaver) Save(msg refs.Message) error {
	_, err := ms.Log.Append(msg)
	return err
}

// mapping an author ref to a verifySink
type verifyFanIn map[string]SequencedVerificationSink

// VerificationRouter hands out sinks (or drains) to pour messages into for verification and storage
type VerificationRouter struct {
	rxlog margaret.Log
	feeds multilog.MultiLog

	saver SaveMessager

	hmacSec *[32]byte

	mu    *sync.Mutex
	sinks verifyFanIn
}

// GetSink returns a verification sink for that author. If called twice for the same author it returns the same drink (for deduplication)
func (vs *VerificationRouter) GetSink(ref refs.FeedRef, complete bool) (SequencedVerificationSink, error) {
	vs.mu.Lock()
	defer vs.mu.Unlock()

	// do we have an open sink for this feed already?
	snk, has := vs.sinks[ref.String()]
	if has {
		return snk, nil
	}
	// no => create a new sink

	// establish latest message we have stored for them
	msg, err := vs.getLatestMsg(ref)
	if err != nil {
		return nil, err
	}

	snk, err = NewVerifySink(ref, msg, vs.saver, vs.hmacSec)
	if err != nil {
		return nil, err
	}

	vs.sinks[ref.String()] = snk
	return snk, nil
}

func (vs *VerificationRouter) CloseSink(ref refs.FeedRef) {
	vs.mu.Lock()
	defer vs.mu.Unlock()
	delete(vs.sinks, ref.String())
}

func firstMessage(author refs.FeedRef) refs.KeyValueRaw {
	return refs.KeyValueRaw{
		Value: refs.Value{
			Previous: nil,
			Author:   author,
			Sequence: 0,
		},
	}
}

func (vs VerificationRouter) getLatestMsg(ref refs.FeedRef) (refs.Message, error) {
	frAddr := storedrefs.Feed(ref)
	userLog, err := vs.feeds.Get(frAddr)
	if err != nil {
		return nil, fmt.Errorf("failed to open sublog for user: %w", err)
	}
	latest := userLog.Seq()

	if latest < 0 {
		return firstMessage(ref), nil
	}

	rxVal, err := userLog.Get(latest)
	if err != nil {
		return nil, fmt.Errorf("failed to look up root seq for latest user sublog: %w", err)
	}
	msgV, err := vs.rxlog.Get(rxVal.(int64))
	if err != nil {
		return nil, fmt.Errorf("failed retreive stored message: %w", err)
	}

	var ok bool
	latestMsg, ok := msgV.(refs.Message)
	if !ok {
		return nil, fmt.Errorf("fetch: wrong message type. expected %T - got %T", latestMsg, msgV)
	}

	return latestMsg, nil

	panic("unreadable")
}
