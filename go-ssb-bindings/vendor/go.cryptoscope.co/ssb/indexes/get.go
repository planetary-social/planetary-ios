// SPDX-License-Identifier: MIT

package indexes

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/repo"
)

const FolderNameGet = "get"

// OpenGet supplies the get(msgRef) -> rootLogSeq idx
func OpenGet(r repo.Interface) (librarian.Index, repo.ServeFunc, error) {
	sinkIdx, serve, err := repo.OpenIndex(r, FolderNameGet, getIDX)
	if err != nil {
		return nil, nil, errors.Wrap(err, "error getting get() index")
	}
	return sinkIdx, serve, nil
}

func getIDX(idx librarian.SeqSetterIndex) librarian.SinkIndex {
	return librarian.NewSinkIndex(func(ctx context.Context, seq margaret.Seq, val interface{}, idx librarian.SetterIndex) error {
		msg, ok := val.(ssb.Message)
		if !ok {
			return errors.Errorf("index/get: unexpected message type: %T", val)
		}
		err := idx.Set(ctx, librarian.Addr(msg.Key().Hash), seq.Seq())
		return errors.Wrapf(err, "index/get: failed to update message %s (seq: %d)", msg.Key().Ref(), seq.Seq())
	}, idx)
}
