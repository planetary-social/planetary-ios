// SPDX-License-Identifier: MIT

package sqlite

import (
	"database/sql"
	"os"
	"path/filepath"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret/internal/persist"
)

type SqliteSaver struct {
	db *sql.DB
}

var _ persist.Saver = (*SqliteSaver)(nil)

func (sl SqliteSaver) Close() error {
	return sl.db.Close()
}

func New(path string) (*SqliteSaver, error) {

	s, err := os.Stat(path)
	if os.IsNotExist(err) {
		if filepath.Dir(path) == "" {
			path = "."
		}
		err = os.MkdirAll(path, 0700)
		if err != nil {
			return nil, errors.Wrap(err, "failed to create path location")
		}
		s, err = os.Stat(path)
		if err != nil {
			return nil, errors.Wrap(err, "failed to stat created path location")
		}
	} else if err != nil {
		return nil, errors.Wrap(err, "failed to stat path location")
	}
	if s.IsDir() {
		path = filepath.Join(path, "log.db")
	}

	db, err := sql.Open("sqlite3", path)
	if err != nil {
		return nil, errors.Wrapf(err, "failed to open sqlite file: %s", path)
	}
	var version int
	err = db.QueryRow(`PRAGMA user_version`).Scan(&version)
	if err == sql.ErrNoRows || version == 0 { // new file or old schema

		if _, err := db.Exec(schemaVersion1); err != nil {
			return nil, errors.Wrap(err, "persist/sqlite: failed to init schema v1")
		}

	} else if err != nil {
		return nil, errors.Wrapf(err, "persist/sqlite: schema version lookup failed %s", path)
	}

	return &SqliteSaver{
		db: db,
	}, nil
}

const schemaVersion1 = `
CREATE TABLE persisted_roaring (
	key varchar PRIMARY KEY,
	data blob
);

PRAGMA user_version = 1;
`
