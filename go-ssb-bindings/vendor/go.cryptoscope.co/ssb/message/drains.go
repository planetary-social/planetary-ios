// SPDX-License-Identifier: MIT

package message

import (
	"bytes"
	"context"
	"encoding/json"
	"time"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/message/legacy"
)

// NewVerifySink returns a sink that does message verification and appends corret messages to the passed log.
// it has to be used on a feed by feed bases, the feed format is decided by the passed feed reference.
// TODO: start and abs could be the same parameter
// TODO: needs configuration for hmac and what not..
// => maybe construct those from a (global) ref register where all the suffixes live with their corresponding network configuration?
func NewVerifySink(who *ssb.FeedRef, start margaret.Seq, abs ssb.Message, snk luigi.Sink, hmacKey *[32]byte) luigi.Sink {

	sd := &streamDrain{
		who:       who,
		latestSeq: margaret.BaseSeq(start.Seq()),
		latestMsg: abs,
		storage:   snk,
	}
	switch who.Algo {
	case ssb.RefAlgoFeedSSB1:
		sd.verify = legacyVerify{hmacKey: hmacKey}
	case ssb.RefAlgoFeedGabby:
		sd.verify = gabbyVerify{hmacKey: hmacKey}
	}
	return sd
}

type verifier interface {
	Verify(v interface{}) (ssb.Message, error)
}

type legacyVerify struct {
	hmacKey *[32]byte
}

func (lv legacyVerify) Verify(v interface{}) (ssb.Message, error) {
	rmsg, ok := v.(json.RawMessage)
	if !ok {
		return nil, errors.Errorf("legacyVerify: expected %T - got %T", rmsg, v)
	}
	ref, dmsg, err := legacy.Verify(rmsg, lv.hmacKey)
	if err != nil {
		return nil, err
	}

	return &legacy.StoredMessage{
		Author_:    &dmsg.Author,
		Previous_:  dmsg.Previous,
		Key_:       ref,
		Sequence_:  dmsg.Sequence,
		Timestamp_: time.Now(),
		Raw_:       rmsg,
	}, nil
}

type gabbyVerify struct {
	hmacKey *[32]byte
}

func (gv gabbyVerify) Verify(v interface{}) (msg ssb.Message, err error) {
	trBytes, ok := v.([]uint8)
	if !ok {
		err = errors.Errorf("gabbyVerify: expected %T - got %T", trBytes, v)
		return
	}
	var tr gabbygrove.Transfer
	if uErr := tr.UnmarshalCBOR(trBytes); uErr != nil {
		err = errors.Wrapf(uErr, "gabbyVerify: transfer unmarshal failed")
		return
	}

	defer func() {
		if r := recover(); r != nil {
			if panicErr, ok := r.(error); ok {
				err = errors.Wrap(panicErr, "gabbyVerify: recovered from panic")
			} else {
				panic(r)
			}
		}
	}()
	if !tr.Verify(gv.hmacKey) {
		return nil, errors.Errorf("gabbyVerify: transfer verify failed")
	}
	msg = &tr
	return
}

type streamDrain struct {
	// gets the input from the screen and returns the next decoded message, if it is valid
	verify verifier

	who *ssb.FeedRef // which feed is pulled

	// holds onto the current/newest method (for sequence check and prev hash compare)
	latestSeq margaret.BaseSeq
	latestMsg ssb.Message

	storage luigi.Sink
}

func (ld *streamDrain) Pour(ctx context.Context, v interface{}) error {
	next, err := ld.verify.Verify(v)
	if err != nil {
		return errors.Wrapf(err, "muxDrain(%s:%d) verify failed", ld.who.ShortRef(), ld.latestSeq.Seq())
	}

	err = ValidateNext(ld.latestMsg, next)
	if err != nil {
		return err
	}

	err = ld.storage.Pour(ctx, next)
	if err != nil {
		return errors.Wrapf(err, "muxDrain(%s): failed to append message(%s:%d)", ld.who.ShortRef(), next.Key().Ref(), next.Seq())
	}

	ld.latestSeq = margaret.BaseSeq(next.Seq())
	ld.latestMsg = next
	return nil
}

func (ld streamDrain) Close() error { return ld.storage.Close() }

// ValidateNext checks the author stays the same across the feed,
// that he previous hash is correct and that the sequence number is increasing correctly
// TODO: move all the message's publish and drains to it's own package
func ValidateNext(current, next ssb.Message) error {
	if current != nil {
		author := current.Author()

		if !author.Equal(next.Author()) {
			return errors.Errorf("ValidateNext(%s:%d): wrong author: %s", author.ShortRef(), current.Seq(), next.Author().ShortRef())
		}

		if bytes.Compare(current.Key().Hash, next.Previous().Hash) != 0 {
			return errors.Errorf("ValidateNext(%s:%d): previous compare failed expected:%s incoming:%s",
				author.Ref(),
				current.Seq(),
				current.Key().Ref(),
				next.Previous().Ref(),
			)
		}
		if current.Seq()+1 != next.Seq() {
			return errors.Errorf("ValidateNext(%s:%d): next.seq != curr.seq+1", author.ShortRef(), current.Seq())
		}

	} else { // first message
		nextSeq := next.Seq()
		if nextSeq != 1 {
			return errors.Errorf("ValidateNext(%s:%d): first message has to have sequence 1", next.Author().ShortRef(), nextSeq)
		}
	}

	return nil
}
