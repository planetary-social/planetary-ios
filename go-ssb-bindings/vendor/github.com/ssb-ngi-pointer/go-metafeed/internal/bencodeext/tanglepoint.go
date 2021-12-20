// SPDX-License-Identifier: MIT

package bencodeext

import (
	"bytes"
	"fmt"

	"github.com/zeebo/bencode"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

// Tangles are a named set of tanglepoints
type Tangles map[string]TanglePoint

// TanglePoint wrapps a normal tanglepoint with bencode marshaling capabilities
type TanglePoint refs.TanglePoint

var (
	_ bencode.Marshaler   = (*TanglePoint)(nil)
	_ bencode.Unmarshaler = (*TanglePoint)(nil)
)

// MarshalBencode encodes root and previous as Null if it's not set. If they are, it turns them into tfk byte strings.
func (tp TanglePoint) MarshalBencode() ([]byte, error) {
	var m = make(map[string]interface{}, 2)

	if tp.Root == nil {
		m["root"] = Null
	} else {
		tfkRoot, err := tfk.MessageFromRef(*tp.Root)
		if err != nil {
			return nil, fmt.Errorf("bencext/tanglePoint: failed to make tfk reference for root message: %w", err)
		}

		m["root"], err = tfkRoot.MarshalBinary()
		if err != nil {
			return nil, fmt.Errorf("bencext/tanglePoint: failed to encode tfk root: %w", err)
		}
	}

	if n := len(tp.Previous); n == 0 {
		m["previous"] = Null
	} else {
		var prevs = make([][]byte, n)

		for i, p := range tp.Previous {
			pTfk, err := tfk.MessageFromRef(p)
			if err != nil {
				return nil, fmt.Errorf("bencext/tanglePoint: failed to make tfk reference for prev message no %d: %w", i, err)
			}

			prevs[i], err = pTfk.MarshalBinary()
			if err != nil {
				return nil, fmt.Errorf("bencext/tanglePoint: failed to encode tfk previous %d: %w", i, err)
			}
		}

		m["previous"] = prevs
	}

	return bencode.EncodeBytes(m)
}

// UnmarshalBencode checks if either are Null and if not, decodes them from tfk.
func (tp *TanglePoint) UnmarshalBencode(input []byte) error {
	var rawBytes struct {
		Root     []byte             `bencode:"root"`
		Previous bencode.RawMessage `bencode:"previous"`
	}

	err := bencode.DecodeBytes(input, &rawBytes)
	if err != nil {
		return fmt.Errorf("bencext/tanglePoint: failed to decode raw bytes: %w", err)
	}

	var candidate refs.TanglePoint

	if bytes.Equal(rawBytes.Root, Null) {
		candidate.Root = nil
	} else {
		var msg tfk.Message
		err = msg.UnmarshalBinary(rawBytes.Root)
		if err != nil {
			return fmt.Errorf("bencext/tanglePoint: failed to unpack root bytes: %w", err)
		}

		root, err := msg.Message()
		if err != nil {
			return fmt.Errorf("bencext/tanglePoint: failed to unpack message from decoded tfk: %w", err)
		}

		candidate.Root = &root
	}

	if bytes.Equal(rawBytes.Previous, NullRawMessage) {
		candidate.Previous = nil
	} else {
		var byteSlices [][]byte
		err := bencode.DecodeBytes(rawBytes.Previous, &byteSlices)
		if err != nil {
			return fmt.Errorf("bencext/tanglePoint: failed to decode byte array for previous hashes: %w", err)
		}
		prevs := make(refs.MessageRefs, len(byteSlices))
		for i, p := range byteSlices {

			var msg tfk.Message
			err = msg.UnmarshalBinary(p)
			if err != nil {
				return fmt.Errorf("bencext/tanglePoint: slice entry %d is not tfk: %w", i, err)
			}

			prevs[i], err = msg.Message()
			if err != nil {
				return fmt.Errorf("bencext/tanglePoint: slice entry %d is not a message: %w", i, err)
			}
		}

		candidate.Previous = prevs
	}

	*tp = TanglePoint(candidate)
	return nil
}
