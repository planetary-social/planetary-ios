// SPDX-License-Identifier: MIT

package message

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"sync"
	"time"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/message/legacy"
)

type publishLog struct {
	sync.Mutex
	margaret.Log
	rootLog margaret.Log

	create creater
}

func (p *publishLog) Publish(content interface{}) (*ssb.MessageRef, error) {
	seq, err := p.Append(content)
	if err != nil {
		return nil, err
	}

	val, err := p.rootLog.Get(seq)
	if err != nil {
		return nil, errors.Wrap(err, "publish: failed to get new stored message")
	}

	kv, ok := val.(ssb.Message)
	if !ok {
		return nil, errors.Errorf("publish: unsupported keyer %T", val)
	}

	key := kv.Key()
	if key == nil {
		return nil, errors.Errorf("publish: nil key for new message %d", seq.Seq())
	}

	return key, nil
}

/* Get retreives the message object by traversing the authors sublog to the root log
func (pl publishLog) Get(s margaret.Seq) (interface{}, error) {

	idxv, err := pl.authorLog.Get(s)
	if err != nil {
		return nil, errors.Wrap(err, "publish get: failed to retreive sequence for the root log")
	}

	msgv, err := pl.rootLog.Get(idxv.(margaret.Seq))
	if err != nil {
		return nil, errors.Wrap(err, "publish get: failed to retreive message from rootlog")
	}
	return msgv, nil
}

TODO: do the same for Query()? but how?

=> just overwrite publish on the authorLog for now
*/
func (pl *publishLog) Append(val interface{}) (margaret.Seq, error) {
	pl.Lock()
	defer pl.Unlock()

	// current state of the local sig-chain
	var (
		nextPrevious *ssb.MessageRef // = invalid
		nextSequence = margaret.SeqEmpty
	)

	currSeq, err := pl.Seq().Value()
	if err != nil {
		return nil, errors.Wrap(err, "publishLog: failed to establish current seq")
	}
	seq, ok := currSeq.(margaret.Seq)
	if !ok {
		return nil, errors.Errorf("publishLog: invalid sequence from publish sublog %v: %T", currSeq, currSeq)
	}

	currRootSeq, err := pl.Get(seq)
	if err != nil && !luigi.IsEOS(err) {
		return nil, errors.Wrap(err, "publishLog: failed to retreive current msg")
	}
	if luigi.IsEOS(err) { // new feed
		nextPrevious = nil
		nextSequence = 1
	} else {
		currMM, err := pl.rootLog.Get(currRootSeq.(margaret.Seq))
		if err != nil {
			return nil, errors.Wrap(err, "publishLog: failed to establish current seq")
		}
		mm, ok := currMM.(ssb.Message)
		if !ok {
			return nil, errors.Errorf("publishLog: invalid value at sequence %v: %T", currSeq, currMM)
		}
		nextPrevious = mm.Key()
		nextSequence = margaret.BaseSeq(mm.Seq() + 1)
	}

	nextMsg, err := pl.create.Create(val, nextPrevious, nextSequence)
	if err != nil {
		return nil, errors.Wrap(err, "failed to create next msg")
	}

	rlSeq, err := pl.rootLog.Append(nextMsg)
	if err != nil {
		return nil, errors.Wrap(err, "failed to append new msg")
	}

	return rlSeq, nil
}

// OpenPublishLog needs the base datastore (root or receive log - offset2)
// and the userfeeds with all the sublog and uses the passed keypair to find the corresponding user feed
// the returned log's append function is then used to create new messages.
// these messages are constructed in the legacy SSB way: The poured object is JSON v8-like pretty printed and then NaCL signed,
// then it's pretty printed again (now with the signature inside the message) to construct it's SHA256 hash,
// which is used to reference it (by replys and it's previous)
func OpenPublishLog(rootLog margaret.Log, sublogs multilog.MultiLog, kp *ssb.KeyPair, opts ...PublishOption) (ssb.Publisher, error) {

	if sublogs == nil {
		return nil, errors.Errorf("no sublog for publish")
	}

	authorLog, err := sublogs.Get(kp.Id.StoredAddr())
	if err != nil {
		return nil, errors.Wrap(err, "publish: failed to open sublog for author")
	}

	pl := &publishLog{
		Log:     authorLog,
		rootLog: rootLog,
	}

	switch kp.Id.Algo {
	case ssb.RefAlgoFeedSSB1:
		pl.create = &legacyCreate{
			key: *kp,
		}
	case ssb.RefAlgoFeedGabby:
		pl.create = &gabbyCreate{
			enc: gabbygrove.NewEncoder(kp),
		}
	default:
		return nil, errors.Errorf("publish: unsupported feed algorithm: %s", kp.Id.Algo)
	}

	for i, o := range opts {
		if err := o(pl); err != nil {
			return nil, errors.Wrapf(err, "publish: option %d failed", i)
		}
	}

	return pl, nil
}

type PublishOption func(*publishLog) error

func SetHMACKey(hmackey []byte) PublishOption {
	return func(pl *publishLog) error {
		var hmacSec [32]byte
		if n := copy(hmacSec[:], hmackey); n != 32 {
			return fmt.Errorf("hmac key of wrong length:%d", n)
		}
		switch cv := pl.create.(type) {
		case *legacyCreate:
			cv.hmac = &hmacSec
		case *gabbyCreate:
			cv.enc.WithHMAC(hmackey)
		default:
			return fmt.Errorf("hmac: unknown creater: %T", cv)
		}
		return nil
	}
}

func UseNowTimestamps(yes bool) PublishOption {
	return func(pl *publishLog) error {
		switch cv := pl.create.(type) {
		case *legacyCreate:
			cv.setTimestamp = yes

		case *gabbyCreate:
			cv.enc.WithNowTimestamps(yes)

		default:
			return fmt.Errorf("setTimestamp: unknown creater: %T", cv)
		}
		return nil
	}
}

type creater interface {
	Create(val interface{}, prev *ssb.MessageRef, seq margaret.Seq) (ssb.Message, error)
}

type legacyCreate struct {
	key          ssb.KeyPair
	hmac         *[32]byte
	setTimestamp bool
}

func (lc legacyCreate) Create(val interface{}, prev *ssb.MessageRef, seq margaret.Seq) (ssb.Message, error) {
	// prepare persisted message
	var stored legacy.StoredMessage
	stored.Timestamp_ = time.Now() // "rx"
	stored.Author_ = lc.key.Id

	// set metadata
	var newMsg legacy.LegacyMessage
	newMsg.Hash = "sha256"
	newMsg.Author = lc.key.Id.Ref()
	newMsg.Previous = prev
	newMsg.Sequence = margaret.BaseSeq(seq.Seq())

	if bindata, ok := val.([]byte); ok {
		bindata = bytes.TrimPrefix(bindata, []byte("box1:"))
		newMsg.Content = base64.StdEncoding.EncodeToString(bindata) + ".box"
	} else {
		newMsg.Content = val
	}

	if lc.setTimestamp {
		newMsg.Timestamp = time.Now().UnixNano() / 1000000
	}

	mr, signedMessage, err := newMsg.Sign(lc.key.Pair.Secret[:], lc.hmac)
	if err != nil {
		return nil, err
	}

	stored.Previous_ = newMsg.Previous
	stored.Sequence_ = newMsg.Sequence
	stored.Key_ = mr
	stored.Raw_ = signedMessage
	return &stored, nil
}

type gabbyCreate struct {
	enc *gabbygrove.Encoder
}

func (pc gabbyCreate) Create(val interface{}, prev *ssb.MessageRef, seq margaret.Seq) (ssb.Message, error) {
	var br *gabbygrove.BinaryRef
	if prev != nil {
		var err error
		br, err = gabbygrove.NewBinaryRef(prev)
		if err != nil {
			return nil, err
		}
	}
	nextSeq := uint64(seq.Seq())
	tr, _, err := pc.enc.Encode(nextSeq, br, val)
	if err != nil {
		return nil, errors.Wrap(err, "gabby: failed to encode content")
	}
	return tr, nil
}
