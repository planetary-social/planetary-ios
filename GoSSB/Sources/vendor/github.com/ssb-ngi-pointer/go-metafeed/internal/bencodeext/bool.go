// SPDX-FileCopyrightText: 2021 The go-metafeed Authors
//
// SPDX-License-Identifier: MIT

package bencodeext

import (
	"bytes"
	"fmt"

	"github.com/zeebo/bencode"
)

// Bool is encoded as a 3 byte string. 0x060100 for false and 0x060101 for true.
type Bool bool

var (
	_ bencode.Marshaler   = (*Bool)(nil)
	_ bencode.Unmarshaler = (*Bool)(nil)
)

var boolPrefix = []byte{'3', ':', 0x06, 0x01}

// MarshalBencode encodes a bool as a string with 3 characters.
func (b Bool) MarshalBencode() ([]byte, error) {
	if b {
		return append(boolPrefix, 0x01), nil
	}
	return append(boolPrefix, 0x00), nil
}

// UnmarshalBencode checks for the two variations '3:\x06\x01\x00" for false and '3:\x06\x01\x01" for true.
func (b *Bool) UnmarshalBencode(input []byte) error {
	if n := len(input); n != 5 {
		return fmt.Errorf("bencodeext: expected 5 bytes for a bool value: %d", n)
	}

	if !bytes.HasPrefix(input, boolPrefix) {
		return fmt.Errorf("bencodeext: wrong prefix for boolean value: %x", input)
	}

	switch input[4] {
	case 0x00:
		*b = false
		return nil
	case 0x01:
		*b = true
		return nil
	default:
		return fmt.Errorf("bencodeext: unexpected value: %x", input[4])
	}
}
