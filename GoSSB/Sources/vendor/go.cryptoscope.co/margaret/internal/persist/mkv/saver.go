// SPDX-License-Identifier: MIT

package mkv

import (
	"bytes"
	"io"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret/internal/persist"
)

const pageSize = 64 * 1024

func (s ModernSaver) Put(key persist.Key, data []byte) error {
	if len(data) < pageSize {
		return s.db.Set(append(key, 0), data)
	}
	var (
		i    int
		page []byte
	)
	for i, page = range splitPages(data) {
		if i > 255 {
			return errors.Errorf("persist/mkv: storage pageing exceeded")
		}
		if err := s.db.Set(append(key, byte(i)), page); err != nil {
			return errors.Wrapf(err, "shard%d set failed", i)
		}
	}
	olderPagers, _, err := s.db.Seek(append(key, byte(i+1)))
	if err != nil {
		return err
	}
	for {
		k, _, err := olderPagers.Next()
		if err != nil {
			if err == io.EOF {
				break
			}
			return errors.Wrap(err, "scraping old pages failed")
		}
		err = s.db.Delete(k)
		if err != nil {
			return err
		}
	}
	return nil
}

func splitPages(data []byte) [][]byte {
	pages := make([][]byte, len(data)/pageSize+1)
	i := 0
	for len(data) > pageSize {
		pages[i], data = data[:pageSize], data[pageSize:]
		i++
	}
	pages[i] = data
	return pages
}

func (s ModernSaver) Get(key persist.Key) ([]byte, error) {
	var data []byte
	enum, _, err := s.db.Seek(key)
	if err != nil {
		return nil, err
	}

	for {
		k, d, err := enum.Next()
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}
		if bytes.Equal(k[:len(k)-1], key) {
			data = append(data, d...)
		} else {
			break
		}
	}
	if len(data) == 0 {
		return nil, persist.ErrNotFound
	}

	return data, nil
}

func (s ModernSaver) List() ([]persist.Key, error) {
	has := make(map[string]struct{})
	var keys []persist.Key
	iter, err := s.db.SeekFirst()
	if err != nil {
		if err == io.EOF {
			return keys, nil
		}
		return nil, err
	}
	for {
		k, _, err := iter.Next()
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}
		pk := persist.Key(k[:len(k)-1])
		if _, hit := has[pk.String()]; !hit {
			keys = append(keys, pk)
			has[pk.String()] = struct{}{}
		}
	}
	return keys, nil
}

func (s ModernSaver) Delete(rm persist.Key) error {
	enum, _, err := s.db.Seek(rm)
	if err != nil {
		return err
	}
	for {
		k, _, err := enum.Next()
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}

		if !bytes.HasPrefix(k, rm) {
			break
		}

		if err := s.db.Delete(k); err != nil {
			return err
		}

	}
	return nil
}
