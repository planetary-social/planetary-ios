// SPDX-License-Identifier: MIT

package indexes

import (
	"github.com/dgraph-io/badger"
	kitlog "github.com/go-kit/kit/log"
	"github.com/pkg/errors"

	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/repo"
)

const FolderNameContacts = "contacts"

func OpenContacts(log kitlog.Logger, r repo.Interface) (graph.Builder, librarian.SeqSetterIndex, librarian.SinkIndex, error) {
	var builder graph.IndexingBuilder
	f := func(db *badger.DB) (librarian.SeqSetterIndex, librarian.SinkIndex) {
		builder = graph.NewBuilder(kitlog.With(log, "module", "graph"), db)
		return builder.OpenIndex()
	}

	_, idx, updateSink, err := repo.OpenBadgerIndex(r, FolderNameContacts, f)
	if err != nil {
		return nil, nil, nil, errors.Wrap(err, "error getting contacts index")
	}

	return builder, idx, updateSink, nil
}
