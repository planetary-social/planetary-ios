// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	stderr "errors"
	"fmt"
	"io"
	"sync"

	"go.cryptoscope.co/muxrpc/v2/codec"
)

// NewPacker takes an io.ReadWriteCloser and returns a Packer.
func NewPacker(rwc io.ReadWriteCloser) *Packer {
	return &Packer{
		r: codec.NewReader(rwc),
		w: codec.NewWriter(rwc),
		c: rwc,

		closing: make(chan struct{}),
	}
}

// Packer is a duplex stream that sends and receives *codec.Packet values.
// Usually wraps a network connection or stdio.
type Packer struct {
	rl sync.Mutex
	wl sync.Mutex

	r *codec.Reader
	w *codec.Writer
	c io.Closer

	cl        sync.Mutex
	closeErr  error
	closeOnce sync.Once
	closing   chan struct{}
}

// Next returns the next packet from the underlying stream.
func (pkr *Packer) NextHeader(ctx context.Context, hdr *codec.Header) error {
	pkr.rl.Lock()
	defer pkr.rl.Unlock()

	err := pkr.r.ReadHeader(hdr)
	select {
	case <-pkr.closing:
		if err != nil {
			return io.EOF
		}
	case <-ctx.Done():
		err := ctx.Err()
		if err != nil {
			return fmt.Errorf("muxrpc/packer: read packet canceled: %w", err)
		}
		return err
	default:
	}

	if err != nil {
		if stderr.Is(err, io.EOF) {
			return io.EOF
		}

		return fmt.Errorf("muxrpc: error reading packet %w", err)
	}

	hdr.Req = -hdr.Req

	return nil
}

// Close closes the packer.
func (pkr *Packer) Close() error {
	pkr.cl.Lock()
	defer pkr.cl.Unlock()
	select {
	case <-pkr.closing:
		if isAlreadyClosed(pkr.closeErr) {
			return nil
		}
		if pkr.closeErr != nil {
			return fmt.Errorf("packer: already closed: %w", pkr.closeErr)
		}
		return nil
	default:
	}

	var err error

	pkr.closeOnce.Do(func() {
		err = pkr.c.Close()
		close(pkr.closing)
	})
	if err != nil {
		err = fmt.Errorf("error closing underlying closer: %w", err)
	}
	pkr.closeErr = err
	return err
}
