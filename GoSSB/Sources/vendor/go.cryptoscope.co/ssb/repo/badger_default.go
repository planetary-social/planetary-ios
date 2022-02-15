// SPDX-License-Identifier: MIT

// +build !nommio

package repo

import (
	"github.com/dgraph-io/badger"
)

func badgerOpts(dbPath string) badger.Options {
	opts := badger.DefaultOptions(dbPath)
	opts.Logger = nil
	return opts

}
