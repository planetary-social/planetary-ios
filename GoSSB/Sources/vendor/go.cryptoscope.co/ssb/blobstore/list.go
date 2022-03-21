// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobstore

import (
	"context"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/luigi"
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
		return fmt.Errorf("error opening blobs directory: %w", err)
	}

	dirs, err := root.Readdir(0)
	if err != nil {
		return fmt.Errorf("error reading blobs directory: %w", err)
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
		return fmt.Errorf("error opening subdirectory: %w", err)
	}

	blobs, err := dir.Readdir(0)
	if err != nil {
		return fmt.Errorf("error reading blobs subdirectory: %w", err)
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
			return nil, fmt.Errorf("error initializing list source: %w", err)
		}
	}

	for len(src.files) == 0 {
		if len(src.dirs) == 0 {
			return nil, luigi.EOS{}
		}

		err := src.nextDir()
		if err != nil {
			return nil, fmt.Errorf("error reading next subdirectory: %w", err)
		}
	}

	var file string
	file, src.files = src.files[0], src.files[1:]

	raw, err := hex.DecodeString(file)
	if err != nil {
		return nil, fmt.Errorf("error decoding hex file name %q: %w", file, err)
	}

	return refs.NewBlobRefFromBytes(raw, refs.RefAlgoBlobSSB1)
}
