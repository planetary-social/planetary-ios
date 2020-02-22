// SPDX-License-Identifier: MIT

package indexes

import (
	"context"

	"github.com/dgraph-io/badger"
	kitlog "github.com/go-kit/kit/log"
	"github.com/pkg/errors"

	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/repo"
)

const FolderNameContacts = "contacts"

func OpenContacts(log kitlog.Logger, r repo.Interface) (graph.Builder, repo.ServeFunc, error) {
	var builder graph.IndexingBuilder
	f := func(db *badger.DB) librarian.SinkIndex {
		builder = graph.NewBuilder(kitlog.With(log, "module", "graph"), db)
		return builder.OpenIndex()
	}

	db, _, serve, err := repo.OpenBadgerIndex(r, FolderNameContacts, f)
	if err != nil {
		return nil, nil, errors.Wrap(err, "error getting contacts index")
	}

	nextServe := func(ctx context.Context, log margaret.Log, live bool) error {
		err := serve(ctx, log, live)
		if err != nil {
			return err
		}

		return db.Close()
	}

	return builder, nextServe, nil
}
