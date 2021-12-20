// SPDX-License-Identifier: MIT

// Package metafeed implements the SSB metafeed spec to enable partial replication.
package metafeed

import (
	"bytes"
	"fmt"
	"time"

	"github.com/ssb-ngi-pointer/go-metafeed/internal/bencodeext"
	"github.com/zeebo/bencode"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

// Payload represents a single Payload on a metafeed.
type Payload struct {
	Author    refs.FeedRef
	Sequence  int
	Previous  *refs.MessageRef
	Timestamp time.Time
	Content   bencode.RawMessage
}

var (
	_ bencode.Marshaler   = (*Payload)(nil)
	_ bencode.Unmarshaler = (*Payload)(nil)
)

// MarshalBencode turns the payload into an array of 5 elements:
// author as tfk, sequence, previous as tfk, timestamp as unix ts and content as a bencode entity (usually object or byte string for box2)
func (p *Payload) MarshalBencode() ([]byte, error) {
	authorAsTFK, err := tfk.FeedFromRef(p.Author)
	if err != nil {
		return nil, fmt.Errorf("metafeed/payload: failed to turn author into a tfk: %w", err)
	}

	autherAsBytes, err := authorAsTFK.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("metafeed/payload: failed to encode author tfk: %w", err)
	}

	var prevAsBytes []byte
	if p.Sequence > 1 {
		if p.Previous == nil {
			return nil, fmt.Errorf("metafeed/payload: previous nil on seq %d", p.Sequence)
		}
		prevMsg, err := tfk.MessageFromRef(*p.Previous)
		if err != nil {
			return nil, fmt.Errorf("metafeed/payload: failed to turn previous into a tfk: %w", err)
		}

		prevAsBytes, err = prevMsg.MarshalBinary()
		if err != nil {
			return nil, fmt.Errorf("metafeed/payload: failed to encode previous tfk: %w", err)
		}
	} else {
		prevAsBytes = bencodeext.Null
	}

	output, err := bencode.EncodeBytes([]interface{}{
		autherAsBytes,
		int32(p.Sequence),
		prevAsBytes,
		p.Timestamp.Unix(),
		p.Content,
	})

	if err != nil {
		return nil, fmt.Errorf("metafeed/payload: failed to encode payload: %w", err)

	}
	if n := len(output); n > maxMessageSize {
		return nil, fmt.Errorf("metafeed/payload: message is too large (%d bytes)", n)
	}

	return output, nil
}

const maxMessageSize = 8192

// UnmarshalBencode does the reverse of MarshalBencode. It expects the input to be a bencoded array of 5 entries.
func (p *Payload) UnmarshalBencode(input []byte) error {
	if n := len(input); n > maxMessageSize {
		return fmt.Errorf("metafeed/payload: message is too large (%d bytes)", n)
	}

	// first, split up the array in raw parts (decodeing to []interface{} is annoying if we know the types anyhow)
	var raw []bencode.RawMessage

	err := bencode.DecodeBytes(input, &raw)
	if err != nil {
		return fmt.Errorf("metafeed/payload: failed to decode raw slices: %w", err)
	}

	if n := len(raw); n != 5 {
		return fmt.Errorf("metafeed/payload: expected at least 5 parts, got %d", n)
	}

	// elem 1: author
	var authorBytes []byte
	err = bencode.DecodeBytes(raw[0], &authorBytes)
	if err != nil {
		return fmt.Errorf("metafeed/payload: failed to get bytes from author position: %w", err)
	}

	var author tfk.Feed
	err = author.UnmarshalBinary(authorBytes)
	if err != nil {
		return fmt.Errorf("metafeed/payload: failed to decode author tfk: %w", err)
	}
	p.Author, err = author.Feed()
	if err != nil {
		return fmt.Errorf("metafeed/payload: invalid author tfk: %w", err)
	}

	if p.Author.Algo() != refs.RefAlgoFeedBendyButt {
		return fmt.Errorf("metafeed/payload: invalid author type: %w", err)
	}

	// elem 2: sequence
	err = bencode.DecodeBytes(raw[1], &p.Sequence)
	if err != nil {
		return fmt.Errorf("metafeed/payload: expected squence: %w", err)
	}

	// elem 3: previous
	var previousBytes []byte
	err = bencode.DecodeBytes(raw[2], &previousBytes)
	if err != nil {
		return fmt.Errorf("metafeed/payload: failed to decode previous bytes: %w", err)
	}

	if p.Sequence == 1 {
		if !bytes.Equal(previousBytes, bencodeext.Null) {
			return fmt.Errorf("metafeed/payload: invalid first message previous entry")
		}
	} else {
		var prev tfk.Message
		err = prev.UnmarshalBinary(previousBytes)
		if err != nil {
			return fmt.Errorf("metafeed/payload: failed to decode previous tfk: %w", err)
		}

		prevMsg, err := prev.Message()
		if err != nil {
			return fmt.Errorf("metafeed/payload: failed to turn previous tfk into a message: %w", err)
		}
		p.Previous = &prevMsg
	}

	// elem 4: timestamp
	var tsInSeconds int64
	err = bencode.DecodeBytes(raw[3], &tsInSeconds)
	if err != nil {
		return fmt.Errorf("metafeed/payload: failed to decode timestamp integer: %w", err)
	}
	p.Timestamp = time.Unix(tsInSeconds, 0)

	// elem 5: content
	p.Content = raw[4]

	return nil
}
