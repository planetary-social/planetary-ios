// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// +build !nommio

package repo

import (
	"github.com/dgraph-io/badger/v3"
)

func badgerOpts(dbPath string) badger.Options {
	opts := badger.DefaultOptions(dbPath)
	opts.Logger = nil
	return opts

}
