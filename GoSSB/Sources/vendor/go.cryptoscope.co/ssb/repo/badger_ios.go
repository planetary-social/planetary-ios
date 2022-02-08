// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

//go:build nommio
// +build nommio

package repo

import (
	"github.com/dgraph-io/badger/v3"
)

func badgerOpts(dbPath string) badger.Options {
	return badger.DefaultOptions(dbPath).
		WithValueLogFileSize(1 << 21).
		WithLogger(nil)
}
