// SPDX-FileCopyrightText: 2021 The margaret Authors
//
// SPDX-License-Identifier: MIT

package fs

import (
	"go.cryptoscope.co/margaret/internal/persist/fs"
	"go.cryptoscope.co/margaret/multilog/roaring"
)

func NewMultiLog(base string) (*roaring.MultiLog, error) {
	return roaring.NewStore(fs.New(base)), nil
}
