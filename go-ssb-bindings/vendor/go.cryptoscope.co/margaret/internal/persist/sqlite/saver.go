// SPDX-License-Identifier: MIT

package sqlite

import (
	"database/sql"
	"encoding/hex"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret/internal/persist"
)

func (s SqliteSaver) Put(key persist.Key, data []byte) error {
	hexKey := hex.EncodeToString(key)
	_, err := s.db.Exec(`insert or replace into persisted_roaring (key,data) VALUES(?,?)`, hexKey, data)
	if err != nil {
		return errors.Wrap(err, "sqlite/put: failed run delete/insert value")
	}
	return nil
}

func (s SqliteSaver) Get(key persist.Key) ([]byte, error) {

	var data []byte
	hexKey := hex.EncodeToString(key)
	err := s.db.QueryRow(`SELECT data from persisted_roaring where key = ?`, hexKey).Scan(&data)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, persist.ErrNotFound
		}
		return nil, errors.Wrapf(err, "persist/sqlite/get(%s): failed to execute query", hexKey[:5])
	}
	return data, nil
}

func (s SqliteSaver) List() ([]persist.Key, error) {
	var keys []persist.Key
	rows, err := s.db.Query(`SELECT key from persisted_roaring`)
	if err != nil {
		return nil, errors.Wrap(err, "persist/sqlite/list: failed to execute rows query")
	}
	defer rows.Close()

	for rows.Next() {
		var k string
		err := rows.Scan(&k)
		if err != nil {
			return nil, errors.Wrap(err, "persist/sqlite/list: failed to scan row result")
		}
		bk, err := hex.DecodeString(k)
		if err != nil {
			return nil, errors.Wrapf(err, "persist/sqlite/list: invalid key: %q", k)
		}
		keys = append(keys, bk)
	}

	return keys, rows.Err()
}

func (s SqliteSaver) Delete(k persist.Key) error {
	hexKey := hex.EncodeToString(k)
	_, err := s.db.Exec(`DELETE FROM persisted_roaring WHERE key = ?`, hexKey)
	if err != nil {
		return errors.Wrapf(err, "sqlite/delete: failed run delete key %q", hexKey)
	}
	return nil
}
