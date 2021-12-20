package sbot

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/RoaringBitmap/roaring"
	"github.com/machinebox/progress"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	kitlog "go.mindeco.de/log"
	"go.mindeco.de/log/level"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/multilogs"
)

// FSCKMode is an enum for the sbot.FSCK function
type FSCKMode uint

const (
	_ FSCKMode = iota

	// FSCKModeLength just checks the feed lengths
	FSCKModeLength

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

type fsckOpt struct {
	feedsIdx   multilog.MultiLog
	mode       FSCKMode
	progressFn FSCKUpdateFunc
}

type FSCKOption func(*fsckOpt) error

func FSCKWithFeedIndex(idx multilog.MultiLog) FSCKOption {
	return func(o *fsckOpt) error {
		o.feedsIdx = idx
		return nil
	}
}

func FSCKWithMode(m FSCKMode) FSCKOption {
	return func(o *fsckOpt) error {
		if m != FSCKModeLength && m != FSCKModeSequences {
			return fmt.Errorf("invalid fsck mode: %d", m)
		}

		o.mode = m
		return nil
	}
}

func FSCKWithProgress(fn FSCKUpdateFunc) FSCKOption {
	return func(o *fsckOpt) error {
		if fn == nil {
			return fmt.Errorf("warning: nil progress func")
		}
		o.progressFn = fn
		return nil
	}
}

// FSCKUpdateFunc is called with the a percentage float between 0 and 100
// and a durration who much time it should take, rounded to seconds.
type FSCKUpdateFunc func(percentage float64, timeLeft time.Duration)

// FSCK checks the consistency of the received messages and the indexes.
// progressFn offers a way to track the progress. It's okay to pass nil, the set sbot.info logger is used in that case.
func (s *Sbot) FSCK(opts ...FSCKOption) error {
	var opt fsckOpt

	for i, o := range opts {
		err := o(&opt)
		if err != nil {
			return fmt.Errorf("sbot/fsck: option #%d failed: %w", i, err)
		}
	}

	if opt.feedsIdx == nil {
		var ok bool
		opt.feedsIdx, ok = s.GetMultiLog(multilogs.IndexNameFeeds)
		if !ok {
			return errors.New("sbot: no users multilog")
		}
	}

	if opt.progressFn == nil {
		opt.progressFn = func(percentage float64, timeLeft time.Duration) {
			level.Info(s.info).Log("event", "fsck-progress", "done", percentage, "time-left", timeLeft.String())
		}
	}

	if opt.mode == 0 { // default to quick check
		opt.mode = FSCKModeLength
	}

	switch opt.mode {
	case FSCKModeLength:
		return lengthFSCK(opt.feedsIdx, s.ReceiveLog)

	case FSCKModeSequences:
		return sequenceFSCK(s.ReceiveLog, opt.progressFn)

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
		return fmt.Errorf("fsck/length: author listing failed: %w", err)
	}

	for _, author := range feeds {
		var sr tfk.Feed
		err := sr.UnmarshalBinary([]byte(author))
		if err != nil {
			return fmt.Errorf("fsck/length: failed to unpack author %q: %w", author, err)
		}

		subLog, err := authorMlog.Get(author)
		if err != nil {
			return fmt.Errorf("fsck/length: failed to get sublog for %q: %w", author, err)
		}

		currentSeqFromIndex := subLog.Seq()

		if currentSeqFromIndex == margaret.SeqEmpty {
			continue
		}

		rxEntry, err := subLog.Get(currentSeqFromIndex)
		if err != nil {
			if margaret.IsErrNulled(err) {
				continue
			}
			return fmt.Errorf("fsck/length: failed to get rxlog entry for index entry %d for author %q: %w", currentSeqFromIndex, author, err)
		}

		rxSeq, ok := rxEntry.(int64)
		if !ok {
			return fmt.Errorf("fsck/length: failed to get rxlog entry for index entry %d for author %q: %w", currentSeqFromIndex, author, err)
		}
		rv, err := receiveLog.Get(rxSeq)
		if err != nil {
			if margaret.IsErrNulled(err) {
				continue
			}
			return fmt.Errorf("fsck/length: failed to load rxlog entry %d for %q: %w", rxSeq, author, err)
		}
		msg := rv.(refs.Message)

		// margaret indexes are 0-based, therefore +1
		if msg.Seq() != currentSeqFromIndex+1 {
			fr, err := sr.Feed()
			if err != nil {
				return fmt.Errorf("fsck/length: failed to feed reference for author (%q): %w", author, err)
			}
			return ssb.ErrWrongSequence{
				Ref:     fr,
				Stored:  currentSeqFromIndex,
				Logical: msg.Seq(),
			}
		}
	}

	return nil
}

// implements machinebox/progress.Counter
type processedCounter struct {
	mu sync.Mutex
	n  int64
}

func (p *processedCounter) Incr() {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.n++
}

func (p *processedCounter) N() int64 {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.n
}

func (p *processedCounter) Err() error { return nil }

// sequenceFSCK goes through every message in the receiveLog
// and checks tha the sequence of a feed is correctly increasing by one each message
func sequenceFSCK(receiveLog margaret.Log, progressFn FSCKUpdateFunc) error {
	ctx := context.Background()

	// the last sequence number we saw of that author
	lastSequence := make(map[string]int64)

	// we need to keep track of _all_ the messages per feed
	// since we dont know in advance which ones we have to null
	allSeqsPerAuthor := make(map[string]*roaring.Bitmap)

	totalMessages := receiveLog.Seq()
	var pc processedCounter

	src, err := receiveLog.Query(margaret.SeqWrap(true))
	if err != nil {
		return err
	}

	// which feeds have problems
	var consistencyErrors []ssb.ErrWrongSequence
	ctx, cancel := context.WithCancel(context.Background())

	go func() {
		p := progress.NewTicker(ctx, &pc, int64(totalMessages), 3*time.Second)
		for remaining := range p {
			estDone := remaining.Estimated()
			// how much time until it's done?
			timeLeft := estDone.Sub(time.Now()).Round(time.Second)
			progressFn(remaining.Percent(), timeLeft)
		}
	}()
	defer cancel()

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

		rxLogSeq := sw.Seq()
		val := sw.Value()
		msg, ok := val.(refs.Message)
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
					Logical: int64(msg.Seq()),
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
				Stored:  int64(currSeq + 1),
				Logical: int64(msg.Seq()),
			}
			consistencyErrors = append(consistencyErrors, seqErr)
			lastSequence[authorRef] = -1
			continue
		}
		lastSequence[authorRef] = currSeq + 1

		// bench stats
		pc.Incr()
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
		err := s.ReceiveLog.Null(int64(seq))
		if err != nil {
			return fmt.Errorf("failed to null message (%d) in receive log: %w", seq, err)
		}
	}

	// now remove feed metadata from the indexes
	for i, constErr := range report.Errors {
		err := s.NullFeed(constErr.Ref)
		if err != nil {
			return fmt.Errorf("heal(%d): failed to null broken feed: %w", i, err)
		}
		level.Debug(funcLog).Log("feed", constErr.Ref.Ref())
	}

	return nil
}
