// SPDX-License-Identifier: MIT

// Package refs strives to offer a couple of types and corresponding encoding code to help other go-based ssb projects to talk about message, feed and blob references without pulling in all of go-ssb and it's network and database code.
package refs

import (
	"bytes"
	"encoding"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"

	"golang.org/x/crypto/ed25519"
)

// Ref is the abstract interface all reference types should implement.
type Ref interface {
	Algo() RefAlgo

	// Sigil returns the pre-URI string ala @foo=.ed25519, %msgkey=.sha256 or &blob=.sha256.
	Sigil() string

	// ShortSigil returns a truncated version of Sigil()
	ShortSigil() string

	// URI prints the reference as a ssb-uri, following https://github.com/ssb-ngi-pointer/ssb-uri-spec
	URI() string

	fmt.Stringer
	encoding.TextMarshaler
}

type RefAlgo string

// Some constant identifiers
const (
	RefAlgoFeedSSB1    RefAlgo = "ed25519" // ssb v1 (legacy, crappy encoding)
	RefAlgoMessageSSB1 RefAlgo = "sha256"  // scuttlebutt happend anyway
	RefAlgoBlobSSB1    RefAlgo = RefAlgoMessageSSB1

	RefAlgoFeedBamboo    RefAlgo = "bamboo"
	RefAlgoMessageBamboo RefAlgo = RefAlgoFeedBamboo

	RefAlgoFeedBendyButt    RefAlgo = "bendybutt-v1"
	RefAlgoMessageBendyButt RefAlgo = RefAlgoFeedBendyButt

	RefAlgoCloakedGroup RefAlgo = "cloaked"

	RefAlgoFeedGabby    RefAlgo = "gabbygrove-v1" // cbor based chain
	RefAlgoMessageGabby RefAlgo = RefAlgoFeedGabby
)

func ParseRef(str string) (Ref, error) {
	if len(str) == 0 {
		return nil, ErrInvalidRef
	}

	switch string(str[0]) {
	case "@":
		return ParseFeedRef(str)
	case "%":
		return ParseMessageRef(str)
	case "&":
		return ParseBlobRef(str)
	default:
		asURL, err := url.Parse(str)
		if err != nil {
			return nil, fmt.Errorf("failed to parse as URL: %s: %w", err, ErrInvalidRefType)
		}
		if asURL.Scheme != "ssb" {
			return nil, fmt.Errorf("expected ssb protocl scheme on URL: %q: %w", str, ErrInvalidRefType)
		}
		asSSBURI, err := parseCaononicalURI(asURL.Opaque)
		return asSSBURI.ref, err
	}
}

// MessageRef defines the content addressed version of a ssb message, identified it's hash.
type MessageRef struct {
	hash [32]byte
	algo RefAlgo
}

func NewMessageRefFromBytes(b []byte, algo RefAlgo) (MessageRef, error) {
	fr := MessageRef{
		algo: algo,
	}
	n := copy(fr.hash[:], b)
	if n != 32 {
		return MessageRef{}, ErrRefLen{algo: fr.algo, n: n}
	}
	return fr, nil
}

func (ref MessageRef) Algo() RefAlgo {
	return ref.algo
}

func (ref MessageRef) Equal(other MessageRef) bool {
	if ref.algo != other.algo {
		return false
	}

	return bytes.Equal(ref.hash[:], other.hash[:])
}

func (ref MessageRef) CopyHashTo(b []byte) error {
	if len(b) != len(ref.hash) {
		return ErrRefLen{algo: ref.algo, n: len(b)}
	}
	copy(b, ref.hash[:])
	return nil
}

// Sigil returns the MessageRef with the sigil %, it's base64 encoded hash and the used algo (currently only sha256)
func (ref MessageRef) Sigil() string {
	return fmt.Sprintf("%%%s.%s", base64.StdEncoding.EncodeToString(ref.hash[:]), ref.algo)
}

// ShortSigil prints a shortend version of Sigil()
func (ref MessageRef) ShortSigil() string {
	return fmt.Sprintf("<%%%s.%s>", base64.StdEncoding.EncodeToString(ref.hash[:3]), ref.algo)
}

func (ref MessageRef) URI() string {
	return CanonicalURI{ref}.String()
}

func (ref MessageRef) String() string {
	if ref.algo == RefAlgoMessageSSB1 || ref.algo == RefAlgoCloakedGroup {
		return ref.Sigil()
	}
	return ref.URI()
}

var (
	_ encoding.TextMarshaler   = (*MessageRef)(nil)
	_ encoding.TextUnmarshaler = (*MessageRef)(nil)
)

func (mr MessageRef) MarshalText() ([]byte, error) {
	if mr.algo == RefAlgoMessageSSB1 || mr.algo == RefAlgoCloakedGroup {
		return []byte(mr.Sigil()), nil
	}
	asURI := CanonicalURI{mr}
	return []byte(asURI.String()), nil
}

func (mr *MessageRef) UnmarshalText(input []byte) error {
	txt := string(input)

	newRef, err := ParseMessageRef(txt)
	if err != nil {
		return err
	}

	*mr = newRef
	return nil
}

func ParseMessageRef(str string) (MessageRef, error) {
	if len(str) == 0 {
		return emptyMsgRef, fmt.Errorf("ssb: msgRef empty")
	}

	split := strings.Split(str[1:], ".")
	if len(split) < 2 {
		asURI, err := parseCaononicalURI(str)
		if err != nil {
			return emptyMsgRef, err
		}

		newRef, ok := asURI.Message()
		if ok {
			return newRef, nil
		}
		return emptyMsgRef, ErrInvalidRef
	}

	raw, err := base64.StdEncoding.DecodeString(split[0])
	if err != nil {
		return emptyMsgRef, fmt.Errorf("msgRef: couldn't parse %q: %s: %w", str, err, ErrInvalidHash)
	}

	if str[0] != '%' {
		return emptyMsgRef, ErrInvalidRefType
	}

	var algo RefAlgo
	switch RefAlgo(split[1]) {
	case RefAlgoMessageSSB1:
		algo = RefAlgoMessageSSB1
	case RefAlgoMessageGabby:
		algo = RefAlgoMessageGabby
	case RefAlgoCloakedGroup:
		algo = RefAlgoCloakedGroup
	default:
		return emptyMsgRef, ErrInvalidRefAlgo
	}
	if n := len(raw); n != 32 {
		return emptyMsgRef, newHashLenError(n)
	}
	newMsg := MessageRef{algo: algo}
	copy(newMsg.hash[:], raw)
	return newMsg, nil
}

type MessageRefs []MessageRef

func (mr *MessageRefs) String() string {
	var s []string
	for _, r := range *mr {
		s = append(s, r.String())
	}
	return strings.Join(s, ", ")
}

func (mr *MessageRefs) UnmarshalJSON(text []byte) error {
	if len(text) == 0 {
		*mr = nil
		return nil
	}

	if bytes.Equal([]byte("[]"), text) || bytes.Equal([]byte("null"), text) {
		*mr = nil
		return nil
	}

	if bytes.HasPrefix(text, []byte("[")) && bytes.HasSuffix(text, []byte("]")) {

		elems := bytes.Split(text[1:len(text)-1], []byte(","))
		newArr := make([]MessageRef, len(elems))

		for i, e := range elems {
			var err error
			r := strings.TrimSpace(string(e))
			r = r[1 : len(r)-1] // remove quotes
			newArr[i], err = ParseMessageRef(r)
			if err != nil {
				return fmt.Errorf("messageRefs %d unmarshal failed: %w", i, err)
			}
		}

		*mr = newArr

	} else {
		newArr := make([]MessageRef, 1)

		var err error
		newArr[0], err = ParseMessageRef(string(text[1 : len(text)-1]))
		if err != nil {
			return fmt.Errorf("messageRefs single unmarshal failed: %w", err)
		}

		*mr = newArr
	}
	return nil
}

// FeedRef defines a publickey as ID with a specific algorithm (currently only ed25519)
type FeedRef struct {
	id   [32]byte
	algo RefAlgo
}

func NewFeedRefFromBytes(b []byte, algo RefAlgo) (FeedRef, error) {
	fr := FeedRef{
		algo: algo,
	}
	n := copy(fr.id[:], b)
	if n != 32 {
		return FeedRef{}, ErrRefLen{algo: fr.algo, n: n}
	}
	return fr, nil
}

func NewLegacyFeedRefFromBytes(b []byte) (FeedRef, error) {
	return NewFeedRefFromBytes(b, RefAlgoFeedSSB1)
}

func (ref FeedRef) PubKey() ed25519.PublicKey {
	return ref.id[:]
}

func (ref FeedRef) Algo() RefAlgo {
	return ref.algo
}

func (ref FeedRef) Equal(b FeedRef) bool {
	if ref.algo != b.algo {
		return false
	}
	return bytes.Equal(ref.id[:], b.id[:])
}

func (ref FeedRef) Sigil() string {
	return fmt.Sprintf("@%s.%s", base64.StdEncoding.EncodeToString(ref.id[:]), ref.algo)
}

func (ref FeedRef) ShortSigil() string {
	return fmt.Sprintf("<@%s.%s>", base64.StdEncoding.EncodeToString(ref.id[:3]), ref.algo)
}

func (ref FeedRef) URI() string {
	return CanonicalURI{ref}.String()
}

func (ref FeedRef) String() string {
	if ref.algo == RefAlgoFeedSSB1 {
		return ref.Sigil()
	}
	return ref.URI()
}

var (
	_ encoding.TextMarshaler   = (*FeedRef)(nil)
	_ encoding.TextUnmarshaler = (*FeedRef)(nil)
)

func (fr FeedRef) MarshalText() ([]byte, error) {
	if fr.algo == RefAlgoFeedSSB1 {
		return []byte(fr.Sigil()), nil
	}
	asURI := CanonicalURI{fr}
	return []byte(asURI.String()), nil
}

func (fr *FeedRef) UnmarshalText(input []byte) error {
	txt := string(input)

	newRef, err := ParseFeedRef(txt)
	if err == nil {
		*fr = newRef
		return nil
	}

	asURI, err := parseCaononicalURI(txt)
	if err != nil {
		return err
	}

	newFeedRef, ok := asURI.Feed()
	if !ok {
		return fmt.Errorf("ssb uri is not a feed ref: %s", asURI.Kind())
	}

	*fr = newFeedRef
	return nil
}

var (
	emptyFeedRef = FeedRef{}
	emptyMsgRef  = MessageRef{}
)

// ParseFeedRef uses ParseRef and checks that it returns a *FeedRef
func ParseFeedRef(str string) (FeedRef, error) {
	if len(str) == 0 {
		return emptyFeedRef, fmt.Errorf("ssb: feedRef empty")
	}

	split := strings.Split(str[1:], ".")
	if len(split) < 2 {
		asURL, err := url.Parse(str)
		if err != nil {
			return emptyFeedRef, fmt.Errorf("failed to parse as URL: %s: %w", err, ErrInvalidRef)
		}
		if asURL.Scheme != "ssb" {
			return emptyFeedRef, fmt.Errorf("expected ssb protocol scheme on URL: %q: %w", str, ErrInvalidRef)
		}
		asSSBURI, err := parseCaononicalURI(asURL.Opaque)
		if err != nil {
			return emptyFeedRef, err
		}
		feedRef, ok := asSSBURI.Feed()
		if !ok {
			return emptyFeedRef, fmt.Errorf("ssbURI is not a feed ref")
		}
		return feedRef, nil
	}

	raw, err := base64.StdEncoding.DecodeString(split[0])
	if err != nil {
		return emptyFeedRef, fmt.Errorf("feedRef: couldn't parse %q: %s: %w", str, err, ErrInvalidHash)
	}

	if str[0] != '@' {
		return emptyFeedRef, ErrInvalidRefType
	}

	var algo RefAlgo
	switch RefAlgo(split[1]) {
	case RefAlgoFeedSSB1:
		algo = RefAlgoFeedSSB1
	case RefAlgoFeedGabby:
		algo = RefAlgoFeedGabby
	case RefAlgoFeedBendyButt:
		algo = RefAlgoFeedBendyButt
	default:
		return emptyFeedRef, fmt.Errorf("unhandled feed algorithm: %s: %w", str, ErrInvalidRefAlgo)
	}

	if n := len(raw); n != 32 {
		return emptyFeedRef, newFeedRefLenError(n)
	}

	newRef := FeedRef{algo: algo}
	copy(newRef.id[:], raw)
	return newRef, nil

}

// BlobRef defines a static binary attachment reference, identified it's hash.
type BlobRef struct {
	hash [32]byte
	algo RefAlgo
}

func NewBlobRefFromBytes(b []byte, algo RefAlgo) (BlobRef, error) {
	ref := BlobRef{
		algo: algo,
	}
	n := copy(ref.hash[:], b)
	if n != 32 {
		return BlobRef{}, ErrRefLen{algo: ref.algo, n: n}
	}
	return ref, nil
}

func (ref BlobRef) Algo() RefAlgo {
	return ref.algo
}

func (ref BlobRef) CopyHashTo(b []byte) error {
	if n := len(b); n != len(ref.hash) {
		return ErrRefLen{algo: "target", n: n}
	}
	copy(b, ref.hash[:])
	return nil
}

// Sigil returns the BlobRef with the sigil &, it's base64 encoded hash and the used algo (currently only sha256)
func (ref BlobRef) Sigil() string {
	return fmt.Sprintf("&%s.%s", base64.StdEncoding.EncodeToString(ref.hash[:]), ref.algo)
}

func (ref BlobRef) ShortSigil() string {
	return fmt.Sprintf("<&%s.%s>", base64.StdEncoding.EncodeToString(ref.hash[:3]), ref.algo)
}

func (ref BlobRef) URI() string {
	return CanonicalURI{ref}.String()
}

func (ref BlobRef) String() string {
	if ref.algo == RefAlgoBlobSSB1 {
		return ref.Sigil()
	}
	return ref.URI()
}

var emptyBlobRef = BlobRef{}

// ParseBlobRef uses ParseRef and checks that it returns a *BlobRef
func ParseBlobRef(str string) (BlobRef, error) {
	if len(str) == 0 {
		return emptyBlobRef, fmt.Errorf("ssb: blob reference empty")
	}

	split := strings.Split(str[1:], ".")
	if len(split) < 2 {
		return emptyBlobRef, ErrInvalidRef
	}

	raw, err := base64.StdEncoding.DecodeString(split[0])
	if err != nil {
		return emptyBlobRef, fmt.Errorf("blob reference: couldn't parse %q: %s: %w", str, err, ErrInvalidHash)
	}

	if str[0] != '&' {
		return emptyBlobRef, ErrInvalidRefType
	}

	var algo RefAlgo
	switch RefAlgo(split[1]) {
	case RefAlgoBlobSSB1:
		algo = RefAlgoBlobSSB1
	default:
		return emptyBlobRef, ErrInvalidRefAlgo
	}
	if n := len(raw); n != 32 {
		return emptyBlobRef, newHashLenError(n)
	}

	newBlob := BlobRef{algo: algo}
	copy(newBlob.hash[:], raw)
	return newBlob, nil
}

func (ref BlobRef) Equal(b BlobRef) bool {
	if ref.algo != b.algo {
		return false
	}
	return bytes.Equal(ref.hash[:], b.hash[:])
}

func (br BlobRef) IsValid() error {
	if br.algo != RefAlgoBlobSSB1 {
		return fmt.Errorf("unknown hash algorithm %q", br.algo)
	}
	if len(br.hash) != 32 {
		return fmt.Errorf("expected hash length 32, got %v", len(br.hash))
	}
	return nil
}

// MarshalText encodes the BlobRef using Ref()
func (br BlobRef) MarshalText() ([]byte, error) {
	return []byte(br.String()), nil
}

// UnmarshalText uses ParseBlobRef
func (br *BlobRef) UnmarshalText(text []byte) error {
	if len(text) == 0 {
		*br = BlobRef{}
		return nil
	}
	newBR, err := ParseBlobRef(string(text))
	if err != nil {
		return fmt.Errorf(" BlobRef/UnmarshalText failed: %w", err)
	}
	*br = newBR
	return nil
}

type AnyRef struct {
	r Ref

	channel string
}

func (ar AnyRef) ShortSigil() string {
	if ar.r == nil {
		panic("empty ref")
	}
	return ar.r.ShortSigil()
}

func (ar AnyRef) Sigil() string {
	if ar.r == nil {
		panic("empty ref")
	}
	return ar.r.Sigil()
}

func (ar AnyRef) URI() string {
	return CanonicalURI{ar}.String()
}

func (ref AnyRef) String() string {
	return ref.r.String()
}

func (ar AnyRef) Algo() RefAlgo {
	return ar.r.Algo()
}

func (ar AnyRef) IsBlob() (BlobRef, bool) {
	br, ok := ar.r.(BlobRef)
	return br, ok
}

func (ar AnyRef) IsFeed() (FeedRef, bool) {
	r, ok := ar.r.(FeedRef)
	return r, ok
}

func (ar AnyRef) IsMessage() (MessageRef, bool) {
	r, ok := ar.r.(MessageRef)
	return r, ok
}

func (ar AnyRef) IsChannel() (string, bool) {
	ok := ar.channel != ""
	return ar.channel, ok
}

func (ar AnyRef) MarshalJSON() ([]byte, error) {
	if ar.r == nil {
		if ar.channel != "" {
			return []byte(`"` + ar.channel + `"`), nil
		}
		return nil, fmt.Errorf("anyRef: not a channel and not a ref")
	}
	refStr, err := ar.r.MarshalText()
	out := append([]byte(`"`), refStr...)
	out = append(out, []byte(`"`)...)
	return out, err
}

func (ar AnyRef) MarshalText() ([]byte, error) {
	return ar.r.MarshalText()
}

func (ar *AnyRef) UnmarshalJSON(b []byte) error {
	if string(b[0:2]) == `"#` {
		ar.channel = string(b[1 : len(b)-1])
		return nil
	}

	if n := len(b); n < 53 {
		return fmt.Errorf("ssb/anyRef: too short: %d: %w", n, ErrInvalidRef)
	}

	var refStr string
	err := json.Unmarshal(b, &refStr)
	if err != nil {
		return fmt.Errorf("ssb/anyRef: not a valid JSON string (%w)", err)
	}

	newRef, err := ParseRef(refStr)
	if err == nil {
		ar.r = newRef
		return nil
	}

	parsedURL, err := url.Parse(refStr)
	if err != nil {
		return fmt.Errorf("ssb/anyRef: parsing (%q) as URL failed: %w", refStr, err)
	}

	asURI, err := parseCaononicalURI(parsedURL.Opaque)
	if err != nil {
		return fmt.Errorf("ssb/anyRef: parsing (%q) as ssb-uri failed: %w", parsedURL.Opaque, err)
	}

	ar.r = asURI.ref
	return nil
}

var (
	_ json.Marshaler   = (*AnyRef)(nil)
	_ json.Unmarshaler = (*AnyRef)(nil)
	_ Ref              = (*AnyRef)(nil)
)
