// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	stderr "errors"
	"io"
	"net"
	"os"
	"sync"
	"syscall"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/codec"

	"github.com/pkg/errors"
)

// Packer is a duplex stream that sends and receives *codec.Packet values.
// Usually wraps a network connection or stdio.
type Packer interface {
	luigi.Source
	luigi.Sink
}

// NewPacker takes an io.ReadWriteCloser and returns a Packer.
func NewPacker(rwc io.ReadWriteCloser) Packer {
	return &packer{
		r: codec.NewReader(rwc),
		w: codec.NewWriter(rwc),
		c: rwc,

		closing: make(chan struct{}),
	}
}

// packer wraps an io.ReadWriteCloser and implements Packer.
type packer struct {
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
func (pkr *packer) Next(ctx context.Context) (interface{}, error) {
	pkr.rl.Lock()
	defer pkr.rl.Unlock()

	pkt, err := pkr.r.ReadPacket()
	select {
	case <-pkr.closing:
		if err != nil {
			return nil, luigi.EOS{}
		}
	case <-ctx.Done():
		return nil, errors.Wrap(ctx.Err(), "muxrpc/packer: read packet canceled")
	default:
	}

	if err != nil {

		if errors.Cause(err) == io.EOF {
			return nil, luigi.EOS{}
		}

		return nil, errors.Wrap(err, "error reading packet")
	}

	pkt.Req = -pkt.Req

	return pkt, nil
}

// Pour sends a packet to the underlying stream.
func (pkr *packer) Pour(ctx context.Context, v interface{}) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-pkr.closing:
		return errSinkClosed
	default:
	}

	pkt, ok := v.(*codec.Packet)
	if !ok {
		return errors.Errorf("packer sink expected type *codec.Packet, got %T", v)
	}

	pkr.wl.Lock()
	defer pkr.wl.Unlock()
	err := pkr.w.WritePacket(pkt)
	if err != nil {

	}

	return errors.Wrap(err, "muxrpc: error writing packet")
}

var errSinkClosed = stderr.New("muxrpc: pour to closed sink")

// IsSinkClosed should be moved to luigi to gether with the error
func IsSinkClosed(err error) bool {
	if err == nil {
		return false
	}
	causeErr := errors.Cause(err)
	if causeErr == errSinkClosed {
		return true
	}

	if causeErr == ErrSessionTerminated {
		return true
	}

	if isAlreadyClosed(err) {
		return true
	}

	return false
}

func isAlreadyClosed(err error) bool {
	if err == nil {
		return false
	}

	causeErr := errors.Cause(err)
	if causeErr == os.ErrClosed || causeErr == io.ErrClosedPipe {
		return true
	}

	if sysErr, ok := (causeErr).(*os.PathError); ok {
		if sysErr.Err == os.ErrClosed {
			// fmt.Printf("debug: found syscall err: %T) %s\n", causeErr, causeErr)
			return true
		}
	}

	if opErr, ok := causeErr.(*net.OpError); ok {
		if syscallErr, ok := opErr.Err.(*os.SyscallError); ok {
			if errNo, ok := syscallErr.Err.(syscall.Errno); ok {
				if errNo == syscall.EPIPE {
					return true
				}
			}
		}
	}
	return false
}

// Close closes the packer.
func (pkr *packer) Close() error {
	pkr.cl.Lock()
	defer pkr.cl.Unlock()
	select {
	case <-pkr.closing:
		if isAlreadyClosed(pkr.closeErr) {
			return nil
		}
		return errors.Wrap(pkr.closeErr, "packer: already closed")
	default:
	}

	var err error

	pkr.closeOnce.Do(func() {
		err = pkr.c.Close()
		close(pkr.closing)
	})
	err = errors.Wrap(err, "error closing underlying closer")
	pkr.closeErr = err
	return err
}
