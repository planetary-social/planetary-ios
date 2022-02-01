package gabbygrove

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"io"
	"math"
	"reflect"
	"time"

	"github.com/pkg/errors"
	"github.com/ugorji/go/codec"
	refs "go.mindeco.de/ssb-refs"
	ssb "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/nacl/auth"
)

// CypherLinkCBORTag is the CBOR tag for a (ssb) cypherlink
// from https://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml#tags
// 888 is WIP and currently unused
const CypherLinkCBORTag = 1050

// GetCBORHandle returns a codec.CborHandle with an extension
// yet to be registerd for SSB References as CBOR tag XXX
func GetCBORHandle() (h *codec.CborHandle) {
	h = new(codec.CborHandle)
	h.IndefiniteLength = false // no streaming
	h.Canonical = true         // sort map keys
	h.SignedInteger = true

	h.StructToArray = true

	var cExt BinRefExt
	h.SetInterfaceExt(reflect.TypeOf(&BinaryRef{}), CypherLinkCBORTag, cExt)
	return h
}

func NewEncoder(author ed25519.PrivateKey) *Encoder {
	pe := &Encoder{}
	pe.privKey = author
	return pe
}

type Encoder struct {
	privKey ed25519.PrivateKey

	hmacSecret   *[32]byte
	setTimestamp bool
}

func (e *Encoder) WithNowTimestamps(yes bool) {
	e.setTimestamp = yes
}

func (e *Encoder) WithHMAC(in []byte) error {
	var k [32]byte
	n := copy(k[:], in)
	if n != 32 {
		return errors.Errorf("hmac key to short: %d", n)
	}
	e.hmacSecret = &k
	return nil
}

var now = time.Now

func (e *Encoder) Encode(sequence uint64, prev BinaryRef, val interface{}) (*Transfer, refs.MessageRef, error) {
	contentHash := sha256.New()
	contentBuf := &bytes.Buffer{}
	w := io.MultiWriter(contentHash, contentBuf)

	// fill the fields of the new event
	var evt Event

	switch tv := val.(type) {
	case []byte:
		evt.Content.Type = ContentTypeArbitrary
		io.Copy(w, bytes.NewReader(tv))
	default:
		evt.Content.Type = ContentTypeJSON
		err := json.NewEncoder(w).Encode(val)
		if err != nil {
			return nil, refs.MessageRef{}, errors.Wrap(err, "json content encoding failed")
		}
	}

	if sequence > 1 {
		evt.Previous = &prev
	}
	evt.Sequence = sequence
	if e.setTimestamp {
		evt.Timestamp = now().Unix()
	}

	var err error
	evt.Author, err = refFromPubKey(e.privKey.Public().(ed25519.PublicKey))
	if err != nil {
		return nil, refs.MessageRef{}, errors.Wrap(err, "invalid author ref")
	}

	cr := ContentRef{
		algo: RefAlgoContentGabby,
	}
	copy(cr.hash[:], contentHash.Sum(nil))

	evt.Content.Hash, err = fromRef(cr)
	if err != nil {
		return nil, refs.MessageRef{}, errors.Wrap(err, "failed to construct content reference")
	}

	n := contentBuf.Len()
	if n > math.MaxUint16 {
		return nil, refs.MessageRef{}, errors.Errorf("gabbygrove: content size too large (got %d bytes)", n)
	}
	evt.Content.Size = uint16(n)
	contentBytes := contentBuf.Bytes()

	evtBytes, err := evt.MarshalCBOR()
	if err != nil {
		return nil, refs.MessageRef{}, errors.Wrap(err, "failed to encode event")
	}

	toSign := evtBytes
	if e.hmacSecret != nil {
		mac := auth.Sum(evtBytes, e.hmacSecret)
		toSign = mac[:]
	}

	var tr Transfer
	tr.Event = evtBytes
	tr.Signature = ed25519.Sign(e.privKey, toSign)
	tr.Content = contentBytes
	return &tr, tr.Key(), nil
}

func (tr Transfer) Key() refs.MessageRef {
	signedEvtHash := sha256.New()
	io.Copy(signedEvtHash, bytes.NewReader(tr.Event))
	io.Copy(signedEvtHash, bytes.NewReader(tr.Signature))

	mr, err := refs.NewMessageRefFromBytes(signedEvtHash.Sum(nil), ssb.RefAlgoMessageGabby)
	if err != nil {
		panic(err)
	}
	return mr
}
