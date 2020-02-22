// SPDX-License-Identifier: MIT

package ssb

import (
	"bytes"
	"encoding"
	"encoding/base64"
	stderr "errors"
	"fmt"
	"net"
	"strings"

	"github.com/pkg/errors"
	"golang.org/x/crypto/ed25519"

	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
)

const (
	RefAlgoFeedSSB1    = "ed25519" // ssb v1 (legacy, crappy encoding)
	RefAlgoMessageSSB1 = "sha256"  // scuttlebutt happend anyway
	RefAlgoBlobSSB1    = RefAlgoMessageSSB1

	RefAlgoFeedGabby    = "ggfeed-v1" // cbor based chain
	RefAlgoMessageGabby = "ggmsg-v1"

	RefAlgoContentGabby = "gabby-v1-content"
)

// Common errors for invalid references
var (
	ErrInvalidRef     = stderr.New("ssb: Invalid Ref")
	ErrInvalidRefType = stderr.New("ssb: Invalid Ref Type")
	ErrInvalidRefAlgo = stderr.New("ssb: Invalid Ref Algo")
	ErrInvalidSig     = stderr.New("ssb: Invalid Signature")
	ErrInvalidHash    = stderr.New("ssb: Invalid Hash")
)

type ErrRefLen struct {
	algo string
	n    int
}

func (e ErrRefLen) Error() string {
	return fmt.Sprintf("ssb: Invalid reference len for %s: %d", e.algo, e.n)
}

func NewFeedRefLenError(n int) error {
	return ErrRefLen{algo: RefAlgoFeedSSB1, n: n}
}

func NewHashLenError(n int) error {
	return ErrRefLen{algo: RefAlgoMessageSSB1, n: n}
}

func ParseRef(str string) (Ref, error) {
	if len(str) == 0 {
		return nil, ErrInvalidRef
	}

	split := strings.Split(str[1:], ".")
	if len(split) < 2 {
		return nil, ErrInvalidRef
	}

	raw, err := base64.StdEncoding.DecodeString(split[0])
	if err != nil { // ???
		raw, err = base64.URLEncoding.DecodeString(split[1])
		if err != nil {
			return nil, errors.Wrapf(ErrInvalidHash, "b64 decode failed (%s)", err)
		}
	}

	switch string(str[0]) {
	case "@":
		var algo string
		switch split[1] {
		case RefAlgoFeedSSB1:
			algo = RefAlgoFeedSSB1
		case RefAlgoFeedGabby:
			algo = RefAlgoFeedGabby
		default:
			return nil, ErrInvalidRefAlgo
		}
		if n := len(raw); n != 32 {
			return nil, NewFeedRefLenError(n)
		}
		return &FeedRef{
			ID:   raw,
			Algo: algo,
		}, nil
	case "%":
		var algo string
		switch split[1] {
		case RefAlgoMessageSSB1:
			algo = RefAlgoMessageSSB1
		case RefAlgoMessageGabby:
			algo = RefAlgoMessageGabby
		default:
			return nil, ErrInvalidRefAlgo
		}
		if n := len(raw); n != 32 {
			return nil, NewHashLenError(n)
		}
		return &MessageRef{
			Hash: raw,
			Algo: algo,
		}, nil
	case "&":
		if split[1] != RefAlgoBlobSSB1 {
			return nil, ErrInvalidRefAlgo
		}
		if n := len(raw); n != 32 {
			return nil, NewHashLenError(n)
		}
		return &BlobRef{
			Hash: raw,
			Algo: RefAlgoBlobSSB1,
		}, nil
	}

	return nil, ErrInvalidRefType
}

type Ref interface {
	Ref() string
}

// MessageRef defines the content addressed version of a ssb message, identified it's hash.
type MessageRef struct {
	Hash []byte
	Algo string
}

func (ref MessageRef) Ref() string {
	return fmt.Sprintf("%%%s.%s", base64.StdEncoding.EncodeToString(ref.Hash), ref.Algo)
}

func (ref MessageRef) Equal(other MessageRef) bool {
	if ref.Algo != other.Algo {
		return false
	}

	return bytes.Equal(ref.Hash, other.Hash)
}

var (
	_ encoding.TextMarshaler   = (*MessageRef)(nil)
	_ encoding.TextUnmarshaler = (*MessageRef)(nil)
)

func (mr MessageRef) MarshalText() ([]byte, error) {
	if len(mr.Hash) == 0 {
		return []byte{}, nil
	}
	return []byte(mr.Ref()), nil
}

func (mr *MessageRef) UnmarshalText(text []byte) error {
	if len(text) == 0 {
		*mr = MessageRef{}
		return nil
	}
	newRef, err := ParseMessageRef(string(text))
	if err != nil {
		return errors.Wrap(err, "message: unmarshal failed")
	}
	*mr = *newRef
	return nil
}

func (r *MessageRef) Scan(raw interface{}) error {
	switch v := raw.(type) {
	case []byte:
		if len(v) != 32 {
			return errors.Errorf("msgRef/Scan: wrong length: %d", len(v))
		}
		r.Hash = v
		r.Algo = RefAlgoMessageSSB1
	case string:
		mr, err := ParseMessageRef(v)
		if err != nil {
			return errors.Wrap(err, "msgRef/Scan: failed to serialze from string")
		}
		*r = *mr
	default:
		return errors.Errorf("msgRef/Scan: unhandled type %T", raw)
	}
	return nil
}

func ParseMessageRef(s string) (*MessageRef, error) {
	ref, err := ParseRef(s)
	if err != nil {
		return nil, errors.Wrap(err, "messageRef: failed to parse ref")
	}
	newRef, ok := ref.(*MessageRef)
	if !ok {
		return nil, errors.Errorf("messageRef: not a message! %T", ref)
	}
	return newRef, nil
}

type MessageRefs []*MessageRef

func (mr *MessageRefs) String() string {
	var s []string
	for _, r := range *mr {
		s = append(s, r.Ref())
	}
	return strings.Join(s, ", ")
}

func (mr *MessageRefs) UnmarshalJSON(text []byte) error {
	if len(text) == 0 {
		*mr = nil
		return nil
	}

	if bytes.Equal([]byte("[]"), text) {
		*mr = nil
		return nil
	}

	if bytes.HasPrefix(text, []byte("[")) && bytes.HasSuffix(text, []byte("]")) {

		elems := bytes.Split(text[1:len(text)-1], []byte(","))
		newArr := make([]*MessageRef, len(elems))

		for i, e := range elems {
			var err error
			r := strings.TrimSpace(string(e))
			r = r[1 : len(r)-1] // remove quotes
			newArr[i], err = ParseMessageRef(r)
			if err != nil {
				return errors.Wrapf(err, "messageRefs %d unmarshal failed", i)
			}
		}

		*mr = newArr

	} else {
		newArr := make([]*MessageRef, 1)

		var err error
		newArr[0], err = ParseMessageRef(string(text[1 : len(text)-1]))
		if err != nil {
			return errors.Wrap(err, "messageRefs single unmarshal failed")
		}

		*mr = newArr
	}
	return nil
}

// FeedRef defines a publickey as ID with a specific algorithm (currently only ed25519)
type FeedRef struct {
	ID   []byte
	Algo string
}

func (ref FeedRef) PubKey() ed25519.PublicKey {
	return ref.ID
}

// StoredAddr returns the key under which this ref is stored in the multilog system
func (ref FeedRef) StoredAddr() librarian.Addr {
	sr, err := NewStorageRef(ref)
	if err != nil {
		panic(errors.Wrap(err, "failed to make storedAddr"))
	}
	b, err := sr.Marshal()
	if err != nil {
		panic(errors.Wrap(err, "error while marshalling addr"))
	}
	return librarian.Addr(b)
}

func (ref FeedRef) Ref() string {
	return fmt.Sprintf("@%s.%s", base64.StdEncoding.EncodeToString(ref.ID), ref.Algo)
}

func (ref FeedRef) Equal(b *FeedRef) bool {
	// TODO: invset time in shs1.1 to signal the format correctly
	// if ref.Algo != b.Algo {
	// 	return false
	// }
	return bytes.Equal(ref.ID, b.ID)
}

var (
	_ encoding.TextMarshaler   = (*FeedRef)(nil)
	_ encoding.TextUnmarshaler = (*FeedRef)(nil)
)

func (fr FeedRef) MarshalText() ([]byte, error) {
	return []byte(fr.Ref()), nil
}

func (fr *FeedRef) UnmarshalText(text []byte) error {
	if len(text) == 0 {
		*fr = FeedRef{}
		return nil
	}
	newRef, err := ParseFeedRef(string(text))
	if err != nil {
		return err
	}
	*fr = *newRef
	return nil
}

func (r *FeedRef) Scan(raw interface{}) error {
	switch v := raw.(type) {
	// TODO: add an extra byte/flag bits to denote algo and types

	// case []byte:
	// 	if len(v) != 32 {
	// 		return errors.Errorf("feedRef/Scan: wrong length: %d", len(v))
	// 	}
	// 	(*r).ID = v
	// 	(*r).Algo = "ed25519"

	case string:
		fr, err := ParseFeedRef(v)
		if err != nil {
			return errors.Wrap(err, "feedRef/Scan: failed to serialize from string")
		}
		*r = *fr
	default:
		return errors.Errorf("feedRef/Scan: unhandled type %T (see TODO)", raw)
	}
	return nil
}

// ParseFeedRef uses ParseRef and checks that it returns a *FeedRef
func ParseFeedRef(s string) (*FeedRef, error) {
	ref, err := ParseRef(s)
	if err != nil {
		return nil, errors.Wrapf(err, "feedRef: couldn't parse %q", s)
	}
	newRef, ok := ref.(*FeedRef)
	if !ok {
		return nil, errors.Errorf("feedRef: not a feed! %T", ref)
	}
	return newRef, nil
}

// GetFeedRefFromAddr uses netwrap to get the secretstream address and then uses ParseFeedRef
func GetFeedRefFromAddr(addr net.Addr) (*FeedRef, error) {
	addr = netwrap.GetAddr(addr, secretstream.NetworkString)
	if addr == nil {
		return nil, errors.New("no shs-bs address found")
	}
	ssAddr := addr.(secretstream.Addr)
	return ParseFeedRef(ssAddr.String())
}

// BlobRef defines a static binary attachment reference, identified it's hash.
type BlobRef struct {
	Hash []byte
	Algo string
}

// Ref returns the BlobRef with the sigil &, it's base64 encoded hash and the used algo (currently only sha256)
func (ref BlobRef) Ref() string {
	return fmt.Sprintf("&%s.%s", base64.StdEncoding.EncodeToString(ref.Hash), ref.Algo)
}

// ParseBlobRef uses ParseRef and checks that it returns a *BlobRef
func ParseBlobRef(s string) (*BlobRef, error) {
	ref, err := ParseRef(s)
	if err != nil {
		return nil, errors.Wrapf(err, "blobRef: failed to parse %q", s)
	}
	newRef, ok := ref.(*BlobRef)
	if !ok {
		return nil, errors.Errorf("blobRef: not a blob! %T", ref)
	}
	return newRef, nil
}

func (ref BlobRef) Equal(b *BlobRef) bool {
	if ref.Algo != b.Algo {
		return false
	}
	return bytes.Equal(ref.Hash, b.Hash)
}

func (br BlobRef) IsValid() error {
	if br.Algo != "sha256" {
		return errors.Errorf("unknown hash algorithm %q", br.Algo)
	}
	if len(br.Hash) != 32 {
		return errors.Errorf("expected hash length 32, got %v", len(br.Hash))
	}
	return nil
}

// MarshalText encodes the BlobRef using Ref()
func (br BlobRef) MarshalText() ([]byte, error) {
	return []byte(br.Ref()), nil
}

// UnmarshalText uses ParseBlobRef
func (br *BlobRef) UnmarshalText(text []byte) error {
	if len(text) == 0 {
		*br = BlobRef{}
		return nil
	}
	newBR, err := ParseBlobRef(string(text))
	if err != nil {
		return errors.Wrap(err, " BlobRef/UnmarshalText failed")
	}
	*br = *newBR
	return nil
}

// ContentRef defines the hashed content of a message
type ContentRef struct {
	Hash []byte
	Algo string
}

func (ref ContentRef) Ref() string {
	return fmt.Sprintf("!%s.%s", base64.StdEncoding.EncodeToString(ref.Hash), ref.Algo)
}

func (ref ContentRef) MarshalBinary() ([]byte, error) {
	switch ref.Algo {
	case RefAlgoContentGabby:
		return append([]byte{0x02}, ref.Hash...), nil
	default:
		return nil, fmt.Errorf("contentRef/Marshal: invalid binref type: %s", ref.Algo)
	}
}

func (ref *ContentRef) UnmarshalBinary(data []byte) error {
	if n := len(data); n != 33 {
		return errors.Errorf("contentRef: invalid len:%d", n)
	}
	var newRef ContentRef
	newRef.Hash = make([]byte, 32)
	switch data[0] {
	case 0x02:
		newRef.Algo = RefAlgoContentGabby
	default:
		return fmt.Errorf("unmarshal: invalid contentRef type: %x", data[0])
	}
	n := copy(newRef.Hash, data[1:])
	if n != 32 {
		return fmt.Errorf("unmarshal: invalid contentRef size: %d", n)
	}
	*ref = newRef
	return nil
}
