// SPDX-License-Identifier: MIT

package sbot

import (
	"io"
	"sync"

	multierror "github.com/hashicorp/go-multierror"
	"github.com/pkg/errors"
)

type multiCloser struct {
	cs []io.Closer
	l  sync.Mutex
}

func (mc *multiCloser) addCloser(c io.Closer) {
	mc.l.Lock()
	defer mc.l.Unlock()

	mc.cs = append(mc.cs, c)
}

func (mc *multiCloser) Close() error {
	var err error

	mc.l.Lock()
	defer mc.l.Unlock()

	for i, c := range mc.cs {
		err = multierror.Append(err, errors.Wrapf(c.Close(), "multiCloser: c%d failed", i))
	}

	me := err.(*multierror.Error)
	if len(me.Errors) == 0 {
		return nil
	}

	return err
}
