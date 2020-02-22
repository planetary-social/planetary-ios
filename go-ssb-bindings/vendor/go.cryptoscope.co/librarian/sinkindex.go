// SPDX-License-Identifier: MIT

package librarian

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
)

type StreamProcFunc func(context.Context, margaret.Seq, interface{}, SetterIndex) error

func NewSinkIndex(f StreamProcFunc, idx SeqSetterIndex) SinkIndex {
	return &sinkIndex{
		idx: idx,
		f:   f,
	}
}

type sinkIndex struct {
	idx SeqSetterIndex
	f   StreamProcFunc
}

func (r *sinkIndex) QuerySpec() margaret.QuerySpec {
	seq, err := r.idx.GetSeq()
	if err != nil {
		// wrap error in erroring queryspec
		return margaret.ErrorQuerySpec(err)
	}

	return margaret.MergeQuerySpec(margaret.Gt(seq), margaret.SeqWrap(true))
}

func (idx *sinkIndex) Pour(ctx context.Context, v interface{}) error {
	seqwrap, ok := v.(margaret.SeqWrapper)
	if !ok {
		return errors.New("expecting seqwrapped value")
	}

	err := idx.f(ctx, seqwrap.Seq(), seqwrap.Value(), idx.idx)
	if err != nil {
		return errors.Wrap(err, "error calling setter func")
	}

	err = idx.idx.SetSeq(seqwrap.Seq())
	return errors.Wrap(err, "error setting sequence number")
}

func (idx *sinkIndex) Close() error {
	// TODO implement index closing
	return nil
}

func (idx *sinkIndex) Get(ctx context.Context, a Addr) (luigi.Observable, error) {
	return idx.idx.Get(ctx, a)
}
