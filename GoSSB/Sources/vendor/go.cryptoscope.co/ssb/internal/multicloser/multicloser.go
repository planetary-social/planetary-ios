// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package multicloser

import (
	"fmt"
	"io"
	"sync"

	multierror "github.com/hashicorp/go-multierror"
)

type MultiCloser struct {
	cs []io.Closer
	l  sync.Mutex
}

func (mc *MultiCloser) AddCloser(c io.Closer) {
	mc.l.Lock()
	defer mc.l.Unlock()

	mc.cs = append(mc.cs, c)
}

var _ io.Closer = (*MultiCloser)(nil)

func (mc *MultiCloser) Close() error {
	mc.l.Lock()
	defer mc.l.Unlock()

	var (
		hasErrs bool
		err     error
	)

	for i, c := range mc.cs {
		if cerr := c.Close(); cerr != nil {
			err = multierror.Append(err, fmt.Errorf("multiCloser: c%d failed: %w", i, cerr))
			hasErrs = true
		}
	}

	if !hasErrs {
		return nil
	}

	return err
}
