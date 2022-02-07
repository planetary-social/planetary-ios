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
	opts := badger.DefaultOptions(dbPath)
	opts.ValueLogFileSize = 1 << 21
	opts.Logger = nil
	// runtime throws MMIO can't allocate errors without this
	// => badger failed to open: Invalid ValueLogLoadingMode, must be FileIO or MemoryMap
	//opts.ValueLogLoadingMode = options.FileIO
	return opts
}
