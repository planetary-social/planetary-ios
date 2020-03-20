package sbot

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/RoaringBitmap/roaring"

	kitlog "github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/multilogs"
)

// FSCKMode is an enum for the sbot.FSCK function
type FSCKMode uint

const (
	// FSCKModeLength just checks the feed lengths
	FSCKModeLength FSCKMode = iota

	// FSCKModeSequences makes sure the sequence field of each message on a feed are increasing correctly
	FSCKModeSequences

	// FSCKModeVerify does a full signature and hash verification
	// FSCKModeVerify
)

type ErrConsistencyProblems struct {
	Errors    []ssb.ErrWrongSequence
	Sequences *roaring.Bitmap
}

func (e ErrConsistencyProblems) Error() string {
	if len(e.Errors) == 1 {
		return e.Errors[0].Error()
	}
	errStr := fmt.Sprintf("ssb: multiple consistency problems (%d) over %d messages", len(e.Errors), e.Sequences.GetCardinality())
	for i, err := range e.Errors {
		errStr += fmt.Sprintf("\n%02d: %s", i, err.Error())
	}
	errStr += "\n"
	return errStr
}

// FSCKUpdateFunc is called with the number of messages left to progress
type FSCKUpdateFunc func(msgsLeft uint64)

// FSCK checks the consistency of the received messages and the indexes.
// progressFn offers a way to track the progress. It's okay to pass nil, stdlib log.Println is used in that case.
func (s *Sbot) FSCK(feedsMlog multilog.MultiLog, mode FSCKMode, progressFn FSCKUpdateFunc) error {
	if feedsMlog == nil {
		var ok bool
		feedsMlog, ok = s.GetMultiLog(multilogs.IndexNameFeeds)
		if !ok {
			return errors.New("sbot: no users multilog")
		}
	}

	if progressFn == nil {
		progressFn = func(left uint64) {
			log.Println("fsck/sequence: messages left to process:", left)
		}
	}

	switch mode {
	case FSCKModeLength:
		return lengthFSCK(feedsMlog, s.RootLog)

	case FSCKModeSequences:
		return sequenceFSCK(s.RootLog, progressFn)

	default:
		return errors.New("sbot: unknown fsck mode")
	}
}

// lengthFSCK just checks the length of each stored feed.
// It expects a multilog as first parameter where each sublog is one feed
// and each entry maps to another entry in the receiveLog
func lengthFSCK(authorMlog multilog.MultiLog, receiveLog margaret.Log) error {
	feeds, err := authorMlog.List()
	if err != nil {
		return err
	}

	for _, author := range feeds {
		var sr ssb.StorageRef
		err := sr.Unmarshal([]byte(author))
		if err != nil {
			return err
		}
		authorRef, err := sr.FeedRef()
		if err != nil {
			return err
		}

		subLog, err := authorMlog.Get(author)
		if err != nil {
			return err
		}

		currentSeqV, err := subLog.Seq().Value()
		if err != nil {
			return err
		}
		currentSeqFromIndex := currentSeqV.(margaret.Seq)
		rlSeq, err := subLog.Get(currentSeqFromIndex)
		if err != nil {
			if margaret.IsErrNulled(err) {
				continue
			}
			return err
		}

		rv, err := receiveLog.Get(rlSeq.(margaret.BaseSeq))
		if err != nil {
			if margaret.IsErrNulled(err) {
				continue
			}
			return err
		}
		msg := rv.(ssb.Message)

		// margaret indexes are 0-based, therefore +1
		if msg.Seq() != currentSeqFromIndex.Seq()+1 {
			return ssb.ErrWrongSequence{
				Ref:     authorRef,
				Stored:  currentSeqFromIndex,
				Logical: msg,
			}
		}
	}

	return nil
}

// sequenceFSCK goes through every message in the receiveLog
// and checks tha the sequence of a feed is correctly increasing by one each message
func sequenceFSCK(receiveLog margaret.Log, progressFn FSCKUpdateFunc) error {
	ctx := context.Background()

	// the last sequence number we saw of that author
	lastSequence := make(map[string]int64)

	// we need to keep track of _all_ the messages per feed
	// since we dont know in advance which ones we have to null
	allSeqsPerAuthor := make(map[string]*roaring.Bitmap)

	currentSeqV, err := receiveLog.Seq().Value()
	if err != nil {
		return err
	}
	currentOffsetSeq := currentSeqV.(margaret.Seq).Seq()
	progressFn(uint64(currentOffsetSeq))

	src, err := receiveLog.Query(margaret.SeqWrap(true))
	if err != nil {
		return err
	}

	// which feeds have problems
	var consistencyErrors []ssb.ErrWrongSequence

	tick := time.NewTicker(5 * time.Second)
	go func() {
		for range tick.C {
			progressFn(uint64(currentOffsetSeq))
		}
	}()
	defer tick.Stop()

	for {
		v, err := src.Next(ctx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			return err
		}

		sw, ok := v.(margaret.SeqWrapper)
		if !ok {
			if errv, ok := v.(error); ok && margaret.IsErrNulled(errv) {
				continue
			}
			return fmt.Errorf("fsck/sw: unexpected message type: %T (wanted %T)", v, sw)
		}

		rxLogSeq := sw.Seq().Seq()
		val := sw.Value()
		msg, ok := val.(ssb.Message)
		if !ok {
			return fmt.Errorf("fsck/value: unexpected message type: %T (wanted %T)", val, msg)
		}

		msgSeq := msg.Seq()
		authorRef := msg.Author().Ref()

		seqMap, ok := allSeqsPerAuthor[authorRef]
		if !ok {
			seqMap = roaring.New()
			allSeqsPerAuthor[authorRef] = seqMap
		}
		seqMap.Add(uint32(rxLogSeq))

		currSeq, has := lastSequence[authorRef]

		if !has {
			if msgSeq != 1 { // not seen yet, so has to be the first
				seqErr := ssb.ErrWrongSequence{
					Ref:     msg.Author(),
					Stored:  sw.Seq(),
					Logical: msg,
				}
				consistencyErrors = append(consistencyErrors, seqErr)
				lastSequence[authorRef] = -1
				continue
			}
			lastSequence[authorRef] = 1
			continue
		}

		if currSeq < 0 { // feed broken, skipping
			continue
		}

		if currSeq+1 != msgSeq { // correct next value?
			seqErr := ssb.ErrWrongSequence{
				Ref:     msg.Author(),
				Stored:  margaret.BaseSeq(currSeq + 1),
				Logical: msg,
			}
			consistencyErrors = append(consistencyErrors, seqErr)
			lastSequence[authorRef] = -1
			continue
		}
		lastSequence[authorRef] = currSeq + 1

		// bench stats
		currentOffsetSeq--
	}

	if len(consistencyErrors) == 0 {
		return nil
	}

	nullMap := roaring.New()
	for _, author := range consistencyErrors {
		if bmap, has := allSeqsPerAuthor[author.Ref.Ref()]; has {
			nullMap.Or(bmap)
		}
	}

	// error report
	return ErrConsistencyProblems{
		Errors:    consistencyErrors,
		Sequences: nullMap,
	}
}

// HealRepo just nulls the messages and is a very naive repair but the only one that is feasably implemented right now
func (s *Sbot) HealRepo(report ErrConsistencyProblems) error {
	funcLog := kitlog.With(s.info, "event", "heal repo")
	brokenCount := len(report.Errors)
	if brokenCount == 0 {
		level.Warn(funcLog).Log("msg", "no errors to repair, run FSCK first.")
		return nil
	}

	level.Info(funcLog).Log("msg", "trying to null all broken feeds",
		"feeds", brokenCount,
		"messages", report.Sequences.GetCardinality(),
	)

	it := report.Sequences.Iterator()
	for it.HasNext() {
		seq := it.Next()
		err := s.RootLog.Null(margaret.BaseSeq(seq))
		if err != nil {
			return errors.Wrapf(err, "failed to null message (%d) in receive log", seq)
		}
		level.Debug(funcLog).Log("msg", seq)
	}

	// now remove feed metadata from the indexes
	for i, constErr := range report.Errors {
		err := s.NullFeed(constErr.Ref)
		if err != nil {
			return errors.Wrapf(err, "heal(%d): failed to null broken feed", i)
		}
		level.Debug(funcLog).Log("feed", constErr.Ref.Ref())
	}

	return nil
}
