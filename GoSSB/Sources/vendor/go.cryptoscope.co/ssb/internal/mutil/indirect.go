// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package mutil offers some margaret utilities.
package mutil

import (
	"context"
	"errors"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
)

type indirectLog struct {
	root, indirect margaret.Log
}

// Indirect returns a new Log uses the "indirection Log" to lookup entries in the "root log".
// This helps with the existing database abstraction where indexes just point to entries in the root log by sequence numbers.
func Indirect(root, indirect margaret.Log) margaret.Log {
	il := indirectLog{
		root:     root,
		indirect: indirect,
	}
	return il
}

func (il indirectLog) Changes() luigi.Observable {
	return il.indirect.Changes()
}

func (il indirectLog) Seq() int64 {
	return il.indirect.Seq()
}

func (il indirectLog) Get(seq int64) (interface{}, error) {
	v, err := il.indirect.Get(seq)
	if err != nil {
		return nil, fmt.Errorf("indirect: 1st lookup failed: %w", err)
	}

	rv, err := il.root.Get(v.(int64))
	if err != nil {
		return nil, fmt.Errorf("indirect: root lookup failed: %w", err)
	}
	return rv, nil
}

// Query returns a stream that is constrained by the passed query specification
func (il indirectLog) Query(args ...margaret.QuerySpec) (luigi.Source, error) {
	src, err := il.indirect.Query(args...)
	if err != nil {
		return nil, fmt.Errorf("error querying: %w", err)
	}

	return mfr.SourceMap(src, func(ctx context.Context, v interface{}) (interface{}, error) {
		vWrapped, isWrapped := v.(margaret.SeqWrapper)
		if isWrapped {
			v = vWrapped.Value()
		}

		vSeq, ok := v.(int64)
		if !ok {
			// if errv, ok := v.(error); ok && margaret.IsErrNulled(errv) {
			// 	continue
			// }
			return nil, errors.New("indirect requires values to be pair with their sequence")
		}

		ret, err := il.root.Get(vSeq)
		if err != nil {
			return nil, err
		}

		if isWrapped {
			ret = margaret.WrapWithSeq(
				ret,
				vWrapped.Seq(),
			)
		}
		return ret, nil
	}), nil
}

// Append appends a new entry to the log
func (il indirectLog) Append(interface{}) (int64, error) {
	return -2, errors.New("can't append to indirected log, sorry")
}
