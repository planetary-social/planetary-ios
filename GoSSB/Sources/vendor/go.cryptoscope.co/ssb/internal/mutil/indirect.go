// SPDX-License-Identifier: MIT

package mutil

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
)

type indirectLog struct {
	root, indirect margaret.Log
}

func Indirect(root, indirect margaret.Log) margaret.Log {
	il := indirectLog{
		root:     root,
		indirect: indirect,
	}
	return il
}

func (il indirectLog) Seq() luigi.Observable {
	return il.indirect.Seq()
}

func (il indirectLog) Get(seq margaret.Seq) (interface{}, error) {
	v, err := il.indirect.Get(seq)
	if err != nil {
		return nil, errors.Wrap(err, "indirect: 1st lookup failed")
	}

	rv, err := il.root.Get(v.(margaret.Seq))
	return rv, errors.Wrap(err, "indirect: root lookup failed")
}

// Query returns a stream that is constrained by the passed query specification
func (il indirectLog) Query(args ...margaret.QuerySpec) (luigi.Source, error) {
	src, err := il.indirect.Query(args...)
	if err != nil {
		return nil, errors.Wrap(err, "error querying")
	}

	return mfr.SourceMap(src, func(ctx context.Context, v interface{}) (interface{}, error) {
		vWrapped, isWrapped := v.(margaret.SeqWrapper)
		if isWrapped {
			v = vWrapped.Value()
		}

		vSeq, ok := v.(margaret.Seq)
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
func (il indirectLog) Append(interface{}) (margaret.Seq, error) {
	return nil, errors.New("can't append to indirected log, sorry")
}
