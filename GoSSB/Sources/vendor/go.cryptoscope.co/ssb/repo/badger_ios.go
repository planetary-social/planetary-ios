// SPDX-License-Identifier: MIT

// +build nommio

package repo

import (
	"github.com/dgraph-io/badger/v3"
	"github.com/dgraph-io/badger/v3/options"
)

func badgerOpts(dbPath string) badger.Options {
	opts := badger.DefaultOptions(dbPath)
	opts.Logger = nil
	// runtime throws MMIO can't allocate errors without this
	// => badger failed to open: Invalid ValueLogLoadingMode, must be FileIO or MemoryMap
	opts.ValueLogLoadingMode = options.FileIO
	return opts
}
