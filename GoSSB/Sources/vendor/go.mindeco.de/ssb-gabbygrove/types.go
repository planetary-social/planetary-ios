package gabbygrove

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"log"
	"math"
	"time"

	"github.com/cryptix/go/encodedTime"

	"github.com/pkg/errors"
	"github.com/ugorji/go/codec"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/nacl/auth"
)

type Event struct {
	Previous  *BinaryRef // %... Metadata hashsha
	Author    *BinaryRef
	Sequence  uint64
	Timestamp int64
	Content   Content
}

// 1 byte to frame the array
// 5 additional bytes for framing of a binRef
// 1 additional byte to frame a (u)int64
const maxEventSize = 1 + 2*(33+5) + 2*(8+1) + maxContentSize

func (evt Event) MarshalCBOR() ([]byte, error) {
	var evtBuf bytes.Buffer
	enc := codec.NewEncoder(&evtBuf, GetCBORHandle())
	if err := enc.Encode(evt); err != nil {
		return nil, errors.Wrap(err, "gabbyGrove/Event: failed to encode to cbor")
	}
	return evtBuf.Bytes(), nil
}

func (evt *Event) UnmarshalCBOR(data []byte) error {
	r := bytes.NewReader(data)
	evtDec := codec.NewDecoder(io.LimitReader(r, maxEventSize), GetCBORHandle())
	return errors.Wrapf(evtDec.Decode(evt), "gabbyGrove/Event: failed to decode")
}

type ContentType uint

const (
	ContentTypeArbitrary ContentType = iota
	ContentTypeJSON
	ContentTypeCBOR
)

type Content struct {
	Hash *BinaryRef
	Size uint16
	Type ContentType
}

// 1 byte to frame the array
// 1 byte for a valid type
// 2 byte for the size
// 5 additional bytes for framing a binRef
const maxContentSize = 1 + 1 + 2 + (33 + 5)

type Transfer struct {
	Event   []byte
	lazyEvt *Event

	Signature []byte
	Content   []byte
}

// 1 byte to frame the array
// 2 additional bytes for "small" byte strings
// 3 additonal bytes for a byte string up to 64k
const maxTransferSize = 1 + (2 + maxEventSize) + (2 + ed25519.SignatureSize) + (3 + math.MaxUint16)

func (tr Transfer) MarshalCBOR() ([]byte, error) {
	var evtBuf bytes.Buffer
	enc := codec.NewEncoder(&evtBuf, GetCBORHandle())
	if err := enc.Encode(tr); err != nil {
		return nil, errors.Wrap(err, "failed to encode transfer")
	}
	return evtBuf.Bytes(), nil
}

func (tr *Transfer) UnmarshalCBOR(data []byte) error {
	r := io.LimitReader(bytes.NewReader(data), maxTransferSize)
	evtDec := codec.NewDecoder(r, GetCBORHandle())
	if err := evtDec.Decode(tr); err != nil {
		return errors.Wrap(err, "failed to decode transfer object")
	}
	// check sizes
	if len(tr.Content) > math.MaxUint16 {
		return errors.Errorf("gabbygrove/transfer: content too large")
	}
	if len(tr.Signature) != ed25519.SignatureSize {
		return errors.Errorf("gabbygrove/transfer: wrong signature size")
	}
	if len(tr.Event) > maxEventSize {
		return errors.Errorf("gabbygrove/transfer: event too large")
	}
	return nil
}

func (tr *Transfer) UnmarshaledEvent() (*Event, error) {
	return tr.getEvent()
}

func (tr *Transfer) getEvent() (*Event, error) {
	if tr.lazyEvt != nil {
		return tr.lazyEvt, nil
	}
	var evt Event
	err := evt.UnmarshalCBOR(tr.Event)
	if err != nil {
		return nil, err
	}
	tr.lazyEvt = &evt
	return &evt, nil
}

// Verify returns true if the Message was signed by the author specified by the meta portion of the message
func (tr *Transfer) Verify(hmacKey *[32]byte) bool {
	evt, err := tr.getEvent()
	if err != nil {
		log.Println("gabbygrove/verify event decoding failed:", err)
		return false
	}
	aref, err := evt.Author.GetRef(RefTypeFeed)
	if err != nil {
		log.Println("gabbygrove/verify getRef failed:", err)
		return false
	}

	pubKey := aref.(*ssb.FeedRef).ID

	toVerify := tr.Event
	if hmacKey != nil {
		mac := auth.Sum(tr.Event, hmacKey)
		toVerify = mac[:]
	}

	return ed25519.Verify(pubKey, toVerify, tr.Signature)
}

var _ ssb.Message = (*Transfer)(nil)

func (tr *Transfer) Seq() int64 {
	evt, err := tr.getEvent()
	if err != nil {
		log.Println("gabbygrove/verify event decoding failed:", err)
		return -1
	}
	return int64(evt.Sequence)
}

func (tr *Transfer) Author() *ssb.FeedRef {
	evt, err := tr.getEvent()
	if err != nil {
		panic(err)
	}
	aref, err := evt.Author.GetRef(RefTypeFeed)
	if err != nil {
		panic(err)
	}
	return aref.(*ssb.FeedRef)
}

func (tr *Transfer) Previous() *ssb.MessageRef {
	evt, err := tr.getEvent()
	if err != nil {
		panic(err)
	}
	if evt.Previous == nil {
		return nil
	}
	mref, err := evt.Previous.GetRef(RefTypeMessage)
	if err != nil {
		panic(err)
	}
	return mref.(*ssb.MessageRef)
}

func (tr *Transfer) Received() time.Time {
	log.Println("received time is spoofed to claimed")
	return tr.Claimed()
}

func (tr *Transfer) Claimed() time.Time {
	evt, err := tr.getEvent()
	if err != nil {
		panic(err)
	}
	return time.Unix(int64(evt.Timestamp), 0)
}

func (tr *Transfer) ContentBytes() []byte {
	return tr.Content
}

// ValueContent returns a ssb.Value that can be represented as JSON.
// Note that it's signature is useless for verification in this form.
// Get the whole transfer message and use tr.Verify()
func (tr *Transfer) ValueContent() *ssb.Value {
	evt, err := tr.getEvent()
	if err != nil {
		panic(err)
	}
	var msg ssb.Value
	if evt.Previous != nil {
		ref, err := evt.Previous.GetRef(RefTypeMessage)
		if err != nil {
			panic(err)
		}
		msg.Previous = ref.(*ssb.MessageRef)
	}
	aref, err := evt.Author.GetRef(RefTypeFeed)
	if err != nil {
		panic(err)
	}
	msg.Author = *aref.(*ssb.FeedRef)
	msg.Sequence = margaret.BaseSeq(evt.Sequence)
	msg.Hash = "gabbygrove-v1"
	msg.Signature = base64.StdEncoding.EncodeToString(tr.Signature) + ".cbor.sig.ed25519"
	msg.Timestamp = encodedTime.Millisecs(tr.Claimed())
	switch evt.Content.Type {
	case ContentTypeArbitrary:
		v, err := json.Marshal(tr.Content)
		if err != nil {
			panic(err)
		}
		msg.Content = json.RawMessage(v)
	case ContentTypeJSON:
		msg.Content = json.RawMessage(tr.Content)
	}
	return &msg
}

func (tr *Transfer) ValueContentJSON() json.RawMessage {
	jsonB, err := json.Marshal(tr.ValueContent())
	if err != nil {
		panic(err.Error())
	}

	return jsonB
}
