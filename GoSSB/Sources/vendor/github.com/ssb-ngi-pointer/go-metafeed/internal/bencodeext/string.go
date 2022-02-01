// SPDX-License-Identifier: MIT

package bencodeext

import (
	"bytes"
	"fmt"
	"strconv"
	"strings"

	"github.com/zeebo/bencode"
)

// String is here since _technically_ bencode only supports byte strings and we want to make extra sure that these are utf8 strings.
type String string

var (
	_ bencode.Marshaler   = (*String)(nil)
	_ bencode.Unmarshaler = (*String)(nil)
)

// MarshalBencode turns the value into a receiver in a byte string with the prefix 0x0600
func (s String) MarshalBencode() ([]byte, error) {
	strLen := len(s) + 2 // two extra bytes for our BFE marker (\x06\x00)

	var sb strings.Builder
	sb.WriteString(strconv.Itoa(strLen))
	sb.WriteRune(':')
	sb.WriteByte(0x06)
	sb.WriteByte(0x00)
	sb.WriteString(string(s))

	return []byte(sb.String()), nil
}

// UnmarshalBencode decodes the length before the : then checks if the prefix of the string is 0x0600
// if so, it updates the receiver with the slice after the prefix marker
func (s *String) UnmarshalBencode(input []byte) error {
	// split the first ':' off (length:value)
	slices := bytes.SplitN(input, []byte{':'}, 2)
	if len(slices) != 2 {
		return fmt.Errorf("bencodeext: expected a length marker")
	}

	strLen, err := strconv.Atoi(string(slices[0]))
	if err != nil {
		return fmt.Errorf("bencodeext: expected integer for length annotation: %w", err)
	}

	if claimed, rest := strLen, len(slices[1]); claimed != rest {
		return fmt.Errorf("bencodeext: expected integer for length annotation (calimed:%d, rest:%d)", claimed, rest)
	}

	if !bytes.HasPrefix(slices[1], []byte{0x06, 0x00}) {
		return fmt.Errorf("bencodeext: value does not have the correct marker")
	}

	*s = String(slices[1][2:])
	return nil
}
