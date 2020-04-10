// SPDX-License-Identifier: MIT

// +build freebsd linux windows darwin,amd64 darwin,386

package repo

import (
	"github.com/dgraph-io/badger"
)

func badgerOpts(dbPath string) badger.Options {
	opts := badger.DefaultOptions(dbPath)
	opts.Logger = nil
	return opts

}
