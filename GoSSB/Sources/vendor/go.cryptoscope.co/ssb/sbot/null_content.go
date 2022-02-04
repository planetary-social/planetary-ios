// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/dgraph-io/badger/v3"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog"
	kitlog "go.mindeco.de/log"
	"go.mindeco.de/log/level"
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/mutil"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message/multimsg"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/repo"
)

// NullContent drops the content portion of a gabbygrove transfer.
// seq is in the same base ase the feed (starting with 1).
func (s *Sbot) NullContent(fr refs.FeedRef, seq uint) error {
	if fr.Algo() != refs.RefAlgoFeedGabby {
		return ssb.ErrUnuspportedFormat
	}

	uf, ok := s.GetMultiLog(multilogs.IndexNameFeeds)
	if !ok {
		return fmt.Errorf("userFeeds mlog not present")
	}

	userLog, err := uf.Get(storedrefs.Feed(fr))
	if err != nil {
		return fmt.Errorf("nullContent: unable to load feed: %w", err)
	}

	// internal data strucutres are 0-indexed
	seqv, err := userLog.Get(int64(seq - 1))
	if err != nil {
		return fmt.Errorf("nullContent: unable to load feed: %w", err)
	}

	rootLogSeq, ok := seqv.(int64)
	if !ok {
		return fmt.Errorf("not a sequence type: %T", seqv)
	}

	msgv, err := s.ReceiveLog.Get(rootLogSeq)
	if err != nil {
		return fmt.Errorf("nullContent: failed to get message in rootLog: %w", err)
	}

	mm, ok := msgv.(*multimsg.MultiMessage)
	if !ok {
		return fmt.Errorf("nullContent: unexpected message type %T", msgv)
	}

	tr, ok := mm.AsGabby()
	if !ok {
		return fmt.Errorf("nullContent: expected gabbyGrove type MultiMessage")
	}

	tr.Content = nil

	nulled, err := mm.MarshalBinary()
	if err != nil {
		return fmt.Errorf("nullContent: unable to marshall nulled content transfer: %w", err)
	}

	err = s.ReceiveLog.Replace(rootLogSeq, nulled)
	if err != nil {
		return fmt.Errorf("nullContent: failed to execute replace operation: %w", err)
	}
	return nil
}

const FolderNameDelete = "drop-content-requests"

type dropContentTrigger struct {
	logger kitlog.Logger

	root  margaret.Log
	feeds multilog.MultiLog

	nuller ssb.ContentNuller

	check chan *triggerEvent
}

type triggerEvent struct {
	author refs.FeedRef
	dcr    ssb.DropContentRequest
}

func (cdr *dropContentTrigger) consume() {
	evtLog := kitlog.With(cdr.logger, "event", "null content trigger")
	for evt := range cdr.check {

		feed, err := cdr.feeds.Get(storedrefs.Feed(evt.author))
		if err != nil {
			level.Warn(evtLog).Log("msg", "no such feed?", "err", err)
			continue
		}

		if !evt.dcr.Valid(mutil.Indirect(cdr.root, feed)) {
			level.Warn(evtLog).Log("msg", "invalid request")
			continue
		}

		err = cdr.nuller.NullContent(evt.author, evt.dcr.Sequence)
		if err != nil {
			level.Error(evtLog).Log("err", err)
			continue
		}

		level.Info(evtLog).Log("msg", "nulled successfully", "author", evt.author.ShortSigil(), "seq", evt.dcr.Sequence)
	}
}

func (dcr *dropContentTrigger) MakeSimpleIndex(db *badger.DB) (librarian.Index, librarian.SinkIndex, error) {

	// TODO: currently the locking of margaret/offset doesn't allow us to get previous messages while being in an index update
	// this is realized as an luigi.Broadcast and the current bases of the index update mechanism
	dcr.check = make(chan *triggerEvent, 10)

	idx, snk, err := repo.OpenIndex(db, FolderNameDelete, dcr.idxupdate)
	if err != nil {
		return nil, nil, fmt.Errorf("error getting dcr trigger index: %w", err)
	}
	go dcr.consume()
	ws := &wrappedIndexSink{SinkIndex: snk, ch: dcr.check}
	return idx, ws, nil
}

type wrappedIndexSink struct {
	librarian.SinkIndex

	ch chan *triggerEvent
}

func (snk *wrappedIndexSink) Close() error {
	close(snk.ch)
	return snk.SinkIndex.Close()
}

func (dcr *dropContentTrigger) idxupdate(idx librarian.SeqSetterIndex) librarian.SinkIndex {
	return librarian.NewSinkIndex(func(ctx context.Context, seq int64, val interface{}, idx librarian.SetterIndex) error {
		if nulled, ok := val.(error); ok {
			if margaret.IsErrNulled(nulled) {
				return nil
			}
			return nulled
		}

		msg, ok := val.(refs.Message)
		if !ok {
			return fmt.Errorf("index/dcrTigger: unexpected message type: %T", val)
		}

		author := msg.Author()
		if author.Algo() != refs.RefAlgoFeedGabby {
			return nil
		}

		var typed ssb.DropContentRequest
		err := json.Unmarshal(msg.ContentBytes(), &typed)
		if err == nil && typed.Type == ssb.DropContentRequestType {
			dcr.check <- &triggerEvent{
				author: author,
				dcr:    typed,
			}
		}

		return nil
	}, idx)
}
