// SPDX-License-Identifier: MIT

// +build darwin
// +build arm arm64

package repo

import (
	"github.com/dgraph-io/badger"
	"github.com/dgraph-io/badger/options"
)

func badgerOpts(dbPath string) badger.Options {
	opts := badger.DefaultOptions(dbPath)
	opts.Logger = nil
	// runtime throws MMIO can't allocate errors without this
	// => badger failed to open: Invalid ValueLogLoadingMode, must be FileIO or MemoryMap
	opts.ValueLogLoadingMode = options.FileIO
	return opts
}
