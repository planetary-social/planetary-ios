// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package slp implements "shallow length prefixed" data. Each element in a slice is prefixed by a uint16 for it's length.
package slp

import (
	"encoding/binary"
	"fmt"
	"math"
)

// encodeUint16 encodes a uint16 with little-endian encoding,
// appends it to out returns the result.
func encodeUint16(out []byte, l uint16) []byte {
	var buf [2]byte
	binary.LittleEndian.PutUint16(buf[:], l)
	return append(out, buf[:]...)
}

// Encode appends the SLP-encoding of a list to out
// and returns the resulting slice.
func Encode(list ...[]byte) ([]byte, error) {
	var out []byte
	for i, elem := range list {
		elemLen := len(elem)
		if elemLen > math.MaxUint16 {
			return nil, fmt.Errorf("slp: element %d (%q) is too long", i, elem)
		}
		out = encodeUint16(out, uint16(elemLen))
		out = append(out, elem...)
	}

	return out, nil
}

// Decode turns an SLP input into a slice of byte slices
func Decode(input []byte) [][]byte {
	var out [][]byte

	for len(input) > 0 {
		// read the length of the current entry
		entryLen := binary.LittleEndian.Uint16(input[:2])

		// splice of the first two bytes
		input = input[2:]

		// cut of the current entry
		out = append(out, input[:entryLen])
		input = input[entryLen:]
	}

	return out
}
