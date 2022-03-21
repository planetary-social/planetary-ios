// SPDX-FileCopyrightText: 2021 The go-metafeed Authors
//
// SPDX-License-Identifier: MIT

package bencodeext

import (
	"bytes"
	"fmt"
	"strconv"
	"strings"

	"github.com/zeebo/bencode"
)

// Bytes is here since _technically_ bencode only supports byte strings and we want to make extra sure that these are arbitrary bytes.
type Bytes []byte

var (
	_ bencode.Marshaler   = (*Bytes)(nil)
	_ bencode.Unmarshaler = (*Bytes)(nil)
)

// MarshalBencode turns the value into a receiver in a byte string with the prefix 0x0603
func (b Bytes) MarshalBencode() ([]byte, error) {
	dataLen := len(b) + 2 // two extra bytes for our BFE marker (\x06\x03)

	var sb strings.Builder
	sb.WriteString(strconv.Itoa(dataLen))
	sb.WriteRune(':')
	sb.WriteByte(0x06)
	sb.WriteByte(0x03)
	sb.WriteString(string(b))

	return []byte(sb.String()), nil
}

// UnmarshalBencode decodes the length before the : then checks if the prefix of the string is 0x0600
// if so, it updates the receiver with the slice after the prefix marker
func (s *Bytes) UnmarshalBencode(input []byte) error {
	// split the first ':' off (length:value)
	slices := bytes.SplitN(input, []byte{':'}, 2)
	if len(slices) != 2 {
		return fmt.Errorf("bencodeext: expected a length marker")
	}

	// indexes in slices
	const (
		idxLen   = 0
		idxValue = 1
	)

	dataLen, err := strconv.Atoi(string(slices[idxLen]))
	if err != nil {
		return fmt.Errorf("bencodeext: expected integer for length annotation: %w", err)
	}

	if claimed, rest := dataLen, len(slices[idxValue]); claimed != rest {
		return fmt.Errorf("bencodeext: expected integer for length annotation (calimed:%d, rest:%d)", claimed, rest)
	}

	if !bytes.HasPrefix(slices[idxValue], []byte{0x06, 0x03}) {
		return fmt.Errorf("bencodeext: value does not have the correct marker")
	}

	*s = Bytes(slices[idxValue][2:])
	return nil
}
