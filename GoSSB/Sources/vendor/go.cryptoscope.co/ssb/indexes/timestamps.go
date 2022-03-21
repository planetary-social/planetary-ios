// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package indexes

import (
	"context"
	"fmt"
	"time"

	"go.cryptoscope.co/margaret"
	mindex "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/ssb/repo"
	refs "go.mindeco.de/ssb-refs"
)

type Timestamps struct {
	resolver *repo.SequenceResolver
}

func NewTimestampSorter(res *repo.SequenceResolver) *Timestamps {
	return &Timestamps{resolver: res}
}

var _ mindex.SinkIndex = (*Timestamps)(nil)

func (idx *Timestamps) Close() error {
	return idx.resolver.Close()
}

func (idx *Timestamps) Pour(ctx context.Context, swv interface{}) error {
	sw, ok := swv.(margaret.SeqWrapper)
	if !ok {
		return fmt.Errorf("error casting seq wrapper. got type %T", swv)
	}
	rxSeq := int64(sw.Seq()) //received as

	v := sw.Value()

	if errV, ok := v.(error); ok {
		if margaret.IsErrNulled(errV) {
			err := idx.resolver.Append(rxSeq, 0, time.Now(), time.Now())
			if err != nil {
				return fmt.Errorf("error updating sequence resolver (nulled message): %w", err)
			}
			return nil
		}
		return errV
	}

	msg, ok := v.(refs.Message)
	if !ok {
		return fmt.Errorf("error casting message. got type %T", v)
	}

	err := idx.resolver.Append(rxSeq, msg.Seq(), msg.Claimed(), msg.Received())
	if err != nil {
		return fmt.Errorf("error updating sequence resolver: %w", err)
	}

	return nil
}

// QuerySpec returns the query spec that queries the next needed messages from the log
func (idx *Timestamps) QuerySpec() margaret.QuerySpec {

	resN := idx.resolver.Seq() - 1

	return margaret.MergeQuerySpec(
		margaret.Gt(resN),
		margaret.SeqWrap(true),
	)
}
