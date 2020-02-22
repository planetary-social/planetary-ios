// SPDX-License-Identifier: MIT

package fs

import (
	"encoding/hex"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret/internal/persist"
)

type Saver struct {
	base string
}

var _ persist.Saver = (*Saver)(nil)

func New(base string) *Saver {
	os.MkdirAll(base, 0700)
	return &Saver{base: base}
}

func (s Saver) Close() error { return nil }

func (s Saver) fnameForKey(k []byte) string {
	var fname string
	hexKey := hex.EncodeToString(k)
	if len(hexKey) > 10 {
		fname = filepath.Join(s.base, hexKey[:5], hexKey[5:])
		os.MkdirAll(filepath.Dir(fname), 0700)
	} else {
		fname = filepath.Join(s.base, hexKey)
	}
	return fname
}

func (s Saver) Put(key persist.Key, data []byte) error {
	err := ioutil.WriteFile(s.fnameForKey(key), data, 0700)
	if err != nil {
		return errors.Wrap(err, "roaringfiles: file write failed")
	}
	return nil
}

func (s Saver) Get(key persist.Key) ([]byte, error) {
	d, err := ioutil.ReadFile(s.fnameForKey(key))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, persist.ErrNotFound
		}
		return nil, errors.Wrap(err, "persist/fs: error in read transaction")
	}
	return d, nil
}

func (s Saver) List() ([]persist.Key, error) {
	var list []persist.Key

	err := filepath.Walk(s.base, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}

		name := strings.TrimPrefix(path, s.base+"/")
		if name[5] == '/' {
			var b = []byte(name)
			b = append(b[:5], b[6:]...)
			name = string(b)
		}
		bk, err := hex.DecodeString(name)
		if err != nil {
			return errors.Wrap(err, "roaringfiles: invalid path")
		}

		list = append(list, bk)
		return nil
	})
	if err != nil {
		return nil, errors.Wrap(err, "persist/fs: walk iteration failed")
	}
	return list, nil
}

func (s Saver) Delete(k persist.Key) error {
	fname := s.fnameForKey(k)
	return os.Remove(fname)
}
