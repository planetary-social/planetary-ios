package sbot

import (
	"context"
	"encoding/json"

	kitlog "github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/mutil"
	"go.cryptoscope.co/ssb/message/multimsg"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/repo"
)

// NullContent drops the content portion of a gabbygrove transfer.
// seq is in the same base ase the feed (starting with 1).
func (s *Sbot) NullContent(fr *ssb.FeedRef, seq uint) error {
	if fr.Algo != ssb.RefAlgoFeedGabby {
		return ssb.ErrUnuspportedFormat
	}

	uf, ok := s.GetMultiLog(multilogs.IndexNameFeeds)
	if !ok {
		return errors.Errorf("userFeeds mlog not present")
	}

	userLog, err := uf.Get(fr.StoredAddr())
	if err != nil {
		return errors.Wrap(err, "nullContent: unable to load feed")
	}

	// internal data strucutres are 0-indexed
	seqv, err := userLog.Get(margaret.BaseSeq(seq - 1))
	if err != nil {
		return errors.Wrap(err, "nullContent: unable to load feed")
	}

	rootLogSeq, ok := seqv.(margaret.Seq)
	if !ok {
		return errors.Errorf("not a sequence type: %T", seqv)
	}

	msgv, err := s.RootLog.Get(rootLogSeq)
	if err != nil {
		return errors.Wrap(err, "nullContent: failed to get message in rootLog")
	}

	mm, ok := msgv.(*multimsg.MultiMessage)
	if !ok {
		return errors.Errorf("nullContent: unexpected message type %T", msgv)
	}

	tr, ok := mm.AsGabby()
	if !ok {
		return errors.Errorf("nullContent: expected gabbyGrove type MultiMessage")
	}

	tr.Content = nil

	nulled, err := mm.MarshalBinary()
	if err != nil {
		return errors.Wrap(err, "nullContent: unable to marshall nulled content transfer")
	}

	err = s.RootLog.Replace(rootLogSeq, nulled)
	return errors.Wrap(err, "nullContent: failed to execute replace operation")
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
	author *ssb.FeedRef
	dcr    *ssb.DropContentRequest
}

func (cdr *dropContentTrigger) consume() {
	evtLog := kitlog.With(cdr.logger, "event", "null content trigger")
	for evt := range cdr.check {

		feed, err := cdr.feeds.Get(evt.author.StoredAddr())
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

		level.Info(evtLog).Log("msg", "nulled successfully", "author", evt.author.ShortRef(), "seq", evt.dcr.Sequence)
	}
}

func (dcr *dropContentTrigger) MakeSimpleIndex(r repo.Interface) (librarian.Index, repo.ServeFunc, error) {

	// TODO: currently the locking of margaret/offset doesn't allow us to get previous messages while being in an index update
	// this is realized as an luigi.Broadcast and the current bases of the index update mechanism
	dcr.check = make(chan *triggerEvent, 10)

	sinkIdx, serve, err := repo.OpenIndex(r, FolderNameDelete, dcr.idxupdate)
	if err != nil {
		return nil, nil, errors.Wrap(err, "error getting dcr trigger index")
	}

	wrappedServe := func(ctx context.Context, log margaret.Log, live bool) error {
		go dcr.consume()
		err := serve(ctx, log, live)
		close(dcr.check)
		return err
	}

	return sinkIdx, wrappedServe, nil
}

func (dcr *dropContentTrigger) idxupdate(idx librarian.SeqSetterIndex) librarian.SinkIndex {
	return librarian.NewSinkIndex(func(ctx context.Context, seq margaret.Seq, val interface{}, idx librarian.SetterIndex) error {
		if nulled, ok := val.(error); ok {
			if margaret.IsErrNulled(nulled) {
				return nil
			}
			return nulled
		}

		msg, ok := val.(ssb.Message)
		if !ok {
			return errors.Errorf("index/dcrTigger: unexpected message type: %T", val)
		}

		author := msg.Author()
		if author.Algo != ssb.RefAlgoFeedGabby {
			return nil
		}

		var typed ssb.DropContentRequest
		err := json.Unmarshal(msg.ContentBytes(), &typed)
		if err == nil && typed.Type == ssb.DropContentRequestType {
			dcr.check <- &triggerEvent{
				author: author,
				dcr:    &typed,
			}
		}

		return nil
	}, idx)
}
