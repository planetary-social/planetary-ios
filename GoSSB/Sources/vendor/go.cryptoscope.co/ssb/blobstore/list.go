// SPDX-License-Identifier: MIT

package blobstore

import (
	"context"
	"encoding/hex"
	"os"
	"path/filepath"
	"sync"

	"github.com/pkg/errors"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/ssb"
)

type listSource struct {
	basePath string

	l     sync.Mutex
	dirs  []string
	files []string
}

func (src *listSource) initialize() error {
	root, err := os.Open(src.basePath)
	if err != nil {
		return errors.Wrap(err, "error opening blobs directory")
	}

	dirs, err := root.Readdir(0)
	if err != nil {
		return errors.Wrap(err, "error reading blobs directory")
	}

	src.dirs = make([]string, len(dirs))
	for i := range dirs {
		src.dirs[i] = dirs[i].Name()
	}

	return nil
}

func (src *listSource) nextDir() error {
	var dirPath string
	dirPath, src.dirs = src.dirs[0], src.dirs[1:]

	dir, err := os.Open(filepath.Join(src.basePath, dirPath))
	if err != nil {
		return errors.Wrap(err, "error opening subdirectory")
	}

	blobs, err := dir.Readdir(0)
	if err != nil {
		return errors.Wrap(err, "error reading blobs subdirectory")
	}

	src.files = make([]string, len(blobs))
	for i := range blobs {
		src.files[i] = dirPath + blobs[i].Name()
	}

	return nil
}

func (src *listSource) Next(ctx context.Context) (interface{}, error) {
	src.l.Lock()
	defer src.l.Unlock()

	if src.dirs == nil {
		err := src.initialize()
		if err != nil {
			return nil, errors.Wrap(err, "error initializing list source")
		}
	}

	for len(src.files) == 0 {
		if len(src.dirs) == 0 {
			return nil, luigi.EOS{}
		}

		err := src.nextDir()
		if err != nil {
			return nil, errors.Wrap(err, "error reading next subdirectory")
		}
	}

	var file string
	file, src.files = src.files[0], src.files[1:]

	raw, err := hex.DecodeString(file)
	if err != nil {
		return nil, errors.Wrapf(err, "error decoding hex file name %q", file)
	}

	return &ssb.BlobRef{
		Algo: "sha256",
		Hash: raw,
	}, nil
}
