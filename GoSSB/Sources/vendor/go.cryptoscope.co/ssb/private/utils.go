// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package private

import (
	"bytes"
	"sort"
)

// bytesSlice attaches the methods of sort.Interface to [][]byte, sorting in increasing order.
type bytesSlice [][]byte

func (p bytesSlice) Len() int { return len(p) }

func (p bytesSlice) Less(i, j int) bool {
	return bytes.Compare(p[i], p[j]) == -1
}

func (p bytesSlice) Swap(i, j int) { p[i], p[j] = p[j], p[i] }

func sortAndConcat(bss ...[]byte) []byte {
	sorter := bytesSlice(bss)
	sort.Sort(sorter)

	var l int
	for _, bs := range sorter {
		l += len(bs)
	}

	var (
		buf = make([]byte, l)
		off int
	)

	for _, bs := range sorter {
		off += copy(buf[off:], bs)
	}

	return buf
}
