// SPDX-License-Identifier: MIT

// Package message contains abstract verification and publish helpers.
package message

import (
	"bytes"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/ssb-ngi-pointer/go-metafeed"
	"go.cryptoscope.co/margaret"

	"go.cryptoscope.co/ssb/message/legacy"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"
	refs "go.mindeco.de/ssb-refs"
)

type SequencedVerificationSink interface {
	margaret.Seqer

	Verify([]byte) error
}

type SaveMessager interface {
	Save(refs.Message) error
}

// NewVerifySink returns a sink that does message verification and appends corret messages to the passed log.
// it has to be used on a feed by feed bases, the feed format is decided by the passed feed reference.
// TODO: start and abs could be the same parameter
// TODO: needs configuration for hmac and what not..
// => maybe construct those from a (global) ref register where all the suffixes live with their corresponding network configuration?
func NewVerifySink(who refs.FeedRef, latest refs.Message, saver SaveMessager, hmacKey *[32]byte) (SequencedVerificationSink, error) {
	drain := &generalVerifyDrain{
		who:       who,
		latestSeq: int64(latest.Seq()),
		latestMsg: latest,
		storage:   saver,
	}
	switch who.Algo() {
	case refs.RefAlgoFeedSSB1:
		drain.verify = &legacyVerify{
			hmacKey: hmacKey,
			buf:     new(bytes.Buffer),
		}

	case refs.RefAlgoFeedGabby:
		drain.verify = &gabbyVerify{hmacKey: hmacKey}

	case refs.RefAlgoFeedBendyButt:
		drain.verify = &metafeedVerify{hmacKey: hmacKey}

	default:
		return nil, fmt.Errorf("NewVerifySink: unsupported feed algorithm %s", who.Algo())

	}
	return drain, nil
}

type verifier interface {
	// Verify checks if a message is valid and returns it or an error if it isn't
	Verify([]byte) (refs.Message, error)
}

type legacyVerify struct {
	hmacKey *[32]byte

	buf *bytes.Buffer
}

func (lv legacyVerify) Verify(rmsg []byte) (refs.Message, error) {
	lv.buf.Reset()
	ref, dmsg, err := legacy.VerifyWithBuffer(rmsg, lv.hmacKey, lv.buf)
	if err != nil {
		return nil, err
	}

	return &legacy.StoredMessage{
		Author_:    dmsg.Author,
		Previous_:  dmsg.Previous,
		Key_:       ref,
		Sequence_:  int64(dmsg.Sequence),
		Timestamp_: time.Now(),
		Raw_:       rmsg,
	}, nil
}

type gabbyVerify struct {
	hmacKey *[32]byte
}

func (gv gabbyVerify) Verify(trBytes []byte) (msg refs.Message, err error) {
	var tr gabbygrove.Transfer
	if uErr := tr.UnmarshalCBOR(trBytes); uErr != nil {
		err = fmt.Errorf("gabbyVerify: transfer unmarshal failed: %w", uErr)
		return
	}

	defer func() {
		// TODO: change cbor encoder in gg
		if r := recover(); r != nil {
			if panicErr, ok := r.(error); ok {
				err = fmt.Errorf("gabbyVerify: recovered from panic: %w", panicErr)
			} else {
				panic(r)
			}
		}
	}()
	if !tr.Verify(gv.hmacKey) {
		return nil, fmt.Errorf("gabbyVerify: transfer verify failed")
	}
	msg = &tr
	return
}

type metafeedVerify struct {
	hmacKey *[32]byte
}

func (mv metafeedVerify) Verify(trBytes []byte) (refs.Message, error) {
	var msg metafeed.Message
	if uErr := msg.UnmarshalBencode(trBytes); uErr != nil {
		return nil, fmt.Errorf("metafeedVerify: message unmarshal failed: %w", uErr)
	}

	if !msg.Verify(mv.hmacKey) {
		return nil, fmt.Errorf("metafeedVerify: verification failed")
	}

	return &msg, nil
}

type generalVerifyDrain struct {
	// gets the input from the screen and returns the next decoded message, if it is valid
	verify verifier

	who refs.FeedRef // which feed is pulled

	// holds onto the current/newest method (for sequence check and prev hash compare)
	mu        sync.Mutex
	latestSeq int64
	latestMsg refs.Message

	storage SaveMessager
}

func (ld *generalVerifyDrain) Seq() int64 {
	ld.mu.Lock()
	defer ld.mu.Unlock()
	return ld.latestSeq
}

// Verify passes the raw message bytes to the verifaction function for the message format (legacy or gabby grove).
// If it passes the message is checked with the current message using ValidateNext().
// If that also passes it is saved to the storage system.
func (ld *generalVerifyDrain) Verify(msg []byte) error {
	ld.mu.Lock()
	defer ld.mu.Unlock()

	next, err := ld.verify.Verify(msg)
	if err != nil {
		return fmt.Errorf("message(%s:%d) verify failed: %w", ld.who.ShortRef(), ld.latestSeq, err)
	}

	err = ValidateNext(ld.latestMsg, next)
	if err != nil {
		if err == errSkip {
			return nil
		}
		return err
	}

	err = ld.storage.Save(next)
	if err != nil {
		return fmt.Errorf("message(%s): failed to append message(%s:%d): %w", ld.who.ShortRef(), next.Key().Ref(), next.Seq(), err)
	}

	ld.latestSeq = int64(next.Seq())
	ld.latestMsg = next
	return nil
}

var errSkip = errors.New("ValidateNext: already got message")

// ValidateNext checks the author stays the same across the feed,
// that he previous hash is correct and that the sequence number is increasing correctly
// TODO: move all the message's publish and drains to it's own package
func ValidateNext(current, next refs.Message) error {
	nextSeq := next.Seq()

	if current == nil || current.Seq() == 0 {
		if nextSeq != 1 {
			return fmt.Errorf("ValidateNext(%s:%d): first message has to have sequence 1, got %d", next.Author().ShortRef(), 0, nextSeq)
		}
		return nil
	}
	currSeq := current.Seq()

	author := current.Author()
	if !author.Equal(next.Author()) {
		return fmt.Errorf("ValidateNext(%s:%d): wrong author: %s", author.ShortRef(), current.Seq(), next.Author().ShortRef())
	}

	if currSeq+1 != nextSeq {
		shouldSkip := next.Seq() <= currSeq
		if shouldSkip {
			return errSkip
		}
		return fmt.Errorf("ValidateNext(%s:%d): next.seq(%d) != curr.seq+1 (skip: %v)", author.ShortRef(), currSeq, nextSeq, shouldSkip)
	}

	currKey := current.Key()
	prev := next.Previous()
	if prev == nil {
		return fmt.Errorf("ValidateNext(%s:%d): previous compare failed expected:%s got nil",
			author.Ref(),
			currSeq,
			current.Key().Ref(),
		)
	}
	if !currKey.Equal(*prev) {
		return fmt.Errorf("ValidateNext(%s:%d): previous compare failed expected:%s incoming:%s",
			author.Ref(),
			currSeq,
			current.Key().Ref(),
			next.Previous().Ref(),
		)
	}

	return nil
}
