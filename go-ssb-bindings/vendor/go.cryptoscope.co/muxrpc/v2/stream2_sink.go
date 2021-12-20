// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"go.cryptoscope.co/muxrpc/v2/codec"
)

type ByteSinker interface {
	io.WriteCloser

	// sometimes we want to close a query early before it is drained
	// (this sends a EndErr packet back )
	CloseWithError(error) error
}

var _ ByteSinker = (*ByteSink)(nil)

// ByteSink exposes a WriteCloser which wrapps each write into a muxrpc packet for that stream with the correct flags set.
type ByteSink struct {
	w *codec.Writer

	closedMu sync.Mutex
	closed   error

	streamCtx context.Context

	pkt codec.Packet
}

func newByteSink(ctx context.Context, w *codec.Writer) *ByteSink {
	return &ByteSink{
		streamCtx: ctx,

		w: w,

		pkt: codec.Packet{},
	}
}

func (bs *ByteSink) SetEncoding(re RequestEncoding) {
	bs.closedMu.Lock()
	defer bs.closedMu.Unlock()
	encFlag, err := re.asCodecFlag()
	if err != nil {
		panic(err)
	}
	bs.pkt.Flag = bs.pkt.Flag.Set(encFlag)
}

func (bs *ByteSink) Write(b []byte) (int, error) {
	bs.closedMu.Lock()
	defer bs.closedMu.Unlock()
	if bs.closed != nil {
		return 0, bs.closed
	}

	// check if the sink was closed since the last write
	select {
	case <-bs.streamCtx.Done():
		bs.closed = bs.streamCtx.Err()
		return 0, bs.closed
	default:
		// no? go on and write!
	}

	if bs.pkt.Req == 0 {
		return -1, fmt.Errorf("req ID not set (Flag: %s)", bs.pkt.Flag)
	}

	bs.pkt.Body = b
	err := bs.w.WritePacket(bs.pkt)
	if err != nil {
		bs.closed = err
		return -1, err
	}
	return len(b), nil
}

func (bs *ByteSink) CloseWithError(err error) error {
	bs.closedMu.Lock()
	defer bs.closedMu.Unlock()

	if bs.closed != nil {
		return bs.closed
	}

	var closePkt codec.Packet
	var isStream = bs.pkt.Flag.Get(codec.FlagStream)
	if err == io.EOF || err == nil {
		closePkt = newEndOkayPacket(bs.pkt.Req, isStream)
	} else {
		var epkt error
		closePkt, epkt = newEndErrPacket(bs.pkt.Req, isStream, err)
		if epkt != nil {
			return fmt.Errorf("close bytesink: error building error packet for %s: %w", err, epkt)
		}
		bs.closed = err
	}

	// tollerate timeout in writing closed packets
	var errc = make(chan error)
	go func() {
		errc <- bs.w.WritePacket(closePkt)
	}()

	select {
	case werr := <-errc:
		if werr != nil {
			bs.closed = werr
		}
		return werr
	case <-time.After(10 * time.Second):
		bs.closed = errors.New("muxrpc: close timeout exceeded")
		return bs.closed
	}

	bs.closed = err
	return nil
}

func (bs *ByteSink) Close() error {
	return bs.CloseWithError(io.EOF)
}
