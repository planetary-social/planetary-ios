package gabbygrove

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"time"

	"go.mindeco.de/encodedTime"

	"github.com/pkg/errors"
	"github.com/ugorji/go/codec"
	refs "go.mindeco.de/ssb-refs"
	ssb "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/nacl/auth"
)

type Event struct {
	Previous  *BinaryRef // %... Metadata hashsha
	Author    BinaryRef
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
	Hash BinaryRef
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

	pubKey := aref.(refs.FeedRef).PubKey()

	toVerify := tr.Event
	if hmacKey != nil {
		mac := auth.Sum(tr.Event, hmacKey)
		toVerify = mac[:]
	}

	return ed25519.Verify(pubKey, toVerify, tr.Signature)
}

var _ refs.Message = (*Transfer)(nil)

func (tr *Transfer) Seq() int64 {
	evt, err := tr.getEvent()
	if err != nil {
		log.Println("gabbygrove/verify event decoding failed:", err)
		return -1
	}
	return int64(evt.Sequence)
}

func (tr *Transfer) Author() refs.FeedRef {
	evt, err := tr.getEvent()
	if err != nil {
		panic(err)
	}
	aref, err := evt.Author.GetRef(RefTypeFeed)
	if err != nil {
		panic(err)
	}
	return aref.(refs.FeedRef)
}

func (tr *Transfer) Previous() *refs.MessageRef {
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
	prevKey := mref.(refs.MessageRef)
	return &prevKey
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
		prevMsg := ref.(refs.MessageRef)
		msg.Previous = &prevMsg
	}
	aref, err := evt.Author.GetRef(RefTypeFeed)
	if err != nil {
		panic(err)
	}
	msg.Author = aref.(refs.FeedRef)
	msg.Sequence = int64(evt.Sequence)
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

var (
	RefAlgoContentGabby refs.RefAlgo = "gabby-v1-content"
)

var _ refs.Ref = ContentRef{}

// ContentRef defines the hashed content of a message
type ContentRef struct {
	hash [32]byte
	algo refs.RefAlgo
}

func NewContentRefFromBytes(b []byte) (ContentRef, error) {
	if n := len(b); n != 32 {
		return ContentRef{}, errors.Errorf("contentRef: invalid len:%d", n)
	}
	var newRef ContentRef
	newRef.algo = RefAlgoContentGabby
	copy(newRef.hash[:], b)
	return newRef, nil
}

func (ref ContentRef) Ref() string {
	return fmt.Sprintf("!%s.%s", base64.StdEncoding.EncodeToString(ref.hash[:]), ref.algo)
}

func (ref ContentRef) ShortRef() string {
	return fmt.Sprintf("<!%s.%s>", base64.StdEncoding.EncodeToString(ref.hash[:3]), ref.algo)
}

func (ref ContentRef) Algo() refs.RefAlgo {
	return RefAlgoContentGabby
}

func (ref ContentRef) MarshalBinary() ([]byte, error) {
	switch ref.algo {
	case RefAlgoContentGabby:
		return append([]byte{0x02}, ref.hash[:]...), nil
	default:
		return nil, fmt.Errorf("contentRef/Marshal: invalid binref type: %s", ref.algo)
	}
}

func (ref *ContentRef) UnmarshalBinary(data []byte) error {
	if n := len(data); n != 33 {
		return errors.Errorf("contentRef: invalid len:%d", n)
	}
	var newRef ContentRef
	switch data[0] {
	case 0x02:
		newRef.algo = RefAlgoContentGabby
	default:
		return fmt.Errorf("unmarshal: invalid contentRef type: %x", data[0])
	}
	n := copy(newRef.hash[:], data[1:])
	if n != 32 {
		return fmt.Errorf("unmarshal: invalid contentRef size: %d", n)
	}
	*ref = newRef
	return nil
}
