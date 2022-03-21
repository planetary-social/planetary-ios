// SPDX-License-Identifier: MIT

package persist

import (
	"encoding/json"
	"os"

	"github.com/pkg/errors"
)

// Save saves a representation of v to the file at path.
func Save(f *os.File, v interface{}) error {
	data, err := json.MarshalIndent(v, "", "\t")
	if err != nil {
		return errors.Wrapf(err, "error marshaling value of type %T", v)
	}

	_, err = f.Seek(0, 0)
	if err != nil {
		return errors.Wrap(err, "error seeking to beginning of file")
	}

	err = f.Truncate(0)
	if err != nil {
		return errors.Wrap(err, "error truncating file")
	}

	_, err = f.Write(data)
	if err != nil {
		return errors.Wrap(err, "error copying data into file")
	}

	_, err = f.Seek(0, 0)
	return errors.Wrap(err, "error seeking to beginning of file")
}

// Load loads the file at path into v.
// Use os.IsNotExist() to see if the returned error is due
// to the file being missing.
func Load(f *os.File, v interface{}) error {
	_, err := f.Seek(0, 0)
	if err != nil {
		return errors.Wrap(err, "error reetting reader")
	}
	err = json.NewDecoder(f).Decode(v)
	return errors.Wrap(err, "error decoding value")
}
