// SPDX-License-Identifier: MIT

package refs

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"strings"
)

//go:generate stringer -trimprefix Kind -type Kind

type Kind uint

const (
	KindUnknown Kind = iota
	KindFeed
	KindMessage
	KindBlob
)

// URI is a SSB universal resource identifier.
// It can be a canonical link for a message, feed or blob.
type URI interface {
	fmt.Stringer

	Feed() (FeedRef, bool)
	Message() (MessageRef, bool)
	Blob() (BlobRef, bool)

	// Type returns a known value of URIKind
	// URI values can also be interface-asserted to Canonical or Experimental URIs
	Kind() Kind
}

// Errors that might be returned by ParseURI
var (
	ErrNotAnURI         = errors.New("ssb: not a known URI scheme")
	ErrNotACanonicalURI = errors.New("ssb: not a caononical URI")
)

// ParseURI either returns a Canonical or an Experimental URI
func ParseURI(input string) (URI, error) {

	u, err := url.Parse(input)
	if err != nil {
		return nil, fmt.Errorf("url.Parse failed: %w", err)
	}

	if u.Scheme != "ssb" {
		return nil, ErrNotAnURI
	}

	if u.Opaque != "" {
		return parseCaononicalURI(u.Opaque)
	}

	return &ExperimentalURI{params: u.Query()}, nil
}

func parseCaononicalURI(input string) (CanonicalURI, error) {
	var c CanonicalURI

	parts := strings.Split(input, "/")
	if len(parts) < 3 {
		return c, ErrNotACanonicalURI
	}

	data, err := base64.URLEncoding.DecodeString(parts[2])
	if err != nil {
		return c, fmt.Errorf("ssb-uri: expected valid base64 url data: %w", err)
	}

	parts[0] = strings.TrimPrefix(parts[0], "ssb:")

	switch parts[0] {
	case "message":
		var r MessageRef
		r.algo = RefAlgo(parts[1])

		if !(r.algo == RefAlgoMessageSSB1 || r.algo == RefAlgoMessageGabby || r.algo == RefAlgoMessageBendyButt) {
			return c, ErrInvalidRefAlgo
		}

		copy(r.hash[:], data)

		c.ref = r

	case "feed":
		var r FeedRef
		r.algo = RefAlgo(parts[1])

		if !(r.algo == RefAlgoFeedSSB1 || r.algo == RefAlgoFeedGabby || r.algo == RefAlgoFeedBendyButt) {
			return c, ErrInvalidRefAlgo
		}

		copy(r.id[:], data)

		c.ref = r

	case "blob":
		var r BlobRef
		r.algo = RefAlgo(parts[1])

		if r.algo != RefAlgoBlobSSB1 {
			return c, ErrInvalidRefAlgo
		}

		copy(r.hash[:], data)

		c.ref = r
	default:

		return c, ErrInvalidRef
	}

	return c, nil
}

// CanonicalURI currently defines 3 different kinds of URIs for Messages, Feeds and Blobs
// See https://github.com/fraction/ssb-uri
type CanonicalURI struct {
	ref Ref
}

func (c CanonicalURI) String() string {
	var u url.URL
	u.Scheme = "ssb"

	var p string
	switch rv := c.ref.(type) {
	case FeedRef:
		algo := c.ref.Algo()
		p = fmt.Sprintf("feed/%s/", algo)
		p += base64.URLEncoding.EncodeToString(rv.id[:])
	case MessageRef:
		algo := c.ref.Algo()
		p = fmt.Sprintf("message/%s/", algo)
		p += base64.URLEncoding.EncodeToString(rv.hash[:])
	case BlobRef:
		p = fmt.Sprintf("blob/%s/", c.ref.Algo())
		p += base64.URLEncoding.EncodeToString(rv.hash[:])
	default:
		p = "undefined"
	}
	u.Opaque = p

	return u.String()
}

func (c CanonicalURI) Kind() Kind {
	switch c.ref.(type) {
	case FeedRef:
		return KindFeed
	case MessageRef:
		return KindMessage
	case BlobRef:
		return KindBlob
	default:
		return KindUnknown
	}
}

func (c CanonicalURI) Feed() (FeedRef, bool) {
	r, ok := c.ref.(FeedRef)
	if !ok {
		return FeedRef{}, false
	}
	return r, true
}

func (c CanonicalURI) Message() (MessageRef, bool) {
	r, ok := c.ref.(MessageRef)
	if !ok {
		return MessageRef{}, false
	}
	return r, true
}

func (c CanonicalURI) Blob() (BlobRef, bool) {
	r, ok := c.ref.(BlobRef)
	if !ok {
		return BlobRef{}, false
	}
	return r, true
}

// ExperimentalURI define magnet-like URIs based on query parameters
// See https://github.com/ssb-ngi-pointer/ssb-uri-spec
type ExperimentalURI struct {
	params url.Values

	// Kind(), Feed(), Message() and Blob() call loadLazyCanon() to parse the "ref" argument just once
	lazyCanonical *CanonicalURI
	lazyErr       error
}

func (e ExperimentalURI) String() string {
	var u url.URL
	u.Scheme = "ssb"
	u.Opaque = "experimental"

	if e.lazyCanonical != nil {
		e.params.Add("ref", e.lazyCanonical.ref.Sigil())
	}

	u.RawQuery = e.params.Encode()

	return u.String()
}

func (e *ExperimentalURI) loadLazyCanon() *CanonicalURI {
	if c := e.lazyCanonical; c != nil {
		return c
	}
	if err := e.tryCanonicalRef(); err != nil {
		e.lazyErr = err
		return nil
	}
	return e.lazyCanonical
}

func (e *ExperimentalURI) tryCanonicalRef() error {
	ref := e.params.Get("ref")
	if ref == "" {
		return ErrNotACanonicalURI
	}

	c, err := parseCaononicalURI(strings.TrimPrefix(ref, "ssb:"))
	if err != nil {
		e.lazyErr = err
		return ErrNotACanonicalURI
	}

	e.lazyCanonical = &c
	return nil
}

func (e *ExperimentalURI) Kind() Kind {
	c := e.loadLazyCanon()
	if e.lazyErr != nil || c == nil {
		return KindUnknown
	}
	return c.Kind()
}

func (e *ExperimentalURI) Feed() (FeedRef, bool) {
	c := e.loadLazyCanon()
	if e.lazyErr != nil || c == nil {
		return FeedRef{}, false
	}
	return c.Feed()
}

func (e *ExperimentalURI) Message() (MessageRef, bool) {
	c := e.loadLazyCanon()
	if e.lazyErr != nil || c == nil {
		return MessageRef{}, false
	}
	return c.Message()
}

func (e *ExperimentalURI) Blob() (BlobRef, bool) {
	c := e.loadLazyCanon()
	if e.lazyErr != nil || c == nil {
		return BlobRef{}, false
	}
	return c.Blob()
}
