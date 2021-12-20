// SPDX-License-Identifier: MIT

package muxrpc

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"sync"
	"sync/atomic"

	"github.com/karrick/bufpool"
	"go.cryptoscope.co/muxrpc/v2/codec"
)

// ReadFn is what a ByteSource needs for it's ReadFn. The passed reader is only valid during the call to it.
type ReadFn func(r io.Reader) error

type ByteSourcer interface {
	Next(context.Context) bool
	Reader(ReadFn) error

	// sometimes we want to close a query early before it is drained
	// (this sends a EndErr packet back )
	Cancel(error)
}

var _ ByteSourcer = (*ByteSource)(nil)

// ByteSource is inspired by sql.Rows but without the Scan(), it just reads plain []bytes, one per muxrpc packet.
type ByteSource struct {
	bpool bufpool.FreeList
	buf   *frameBuffer

	mu     sync.Mutex
	closed chan struct{}
	failed error

	hdrFlag codec.Flag

	streamCtx context.Context
	cancel    context.CancelFunc
}

func newByteSource(ctx context.Context, pool bufpool.FreeList) *ByteSource {
	bs := &ByteSource{
		bpool: pool,
		buf: &frameBuffer{
			store: pool.Get(),
		},
		closed: make(chan struct{}),
	}
	bs.streamCtx, bs.cancel = context.WithCancel(ctx)

	return bs
}

// Cancel stops reading and terminates the request.
// Sometimes we want to close a query early before it is drained.
func (bs *ByteSource) Cancel(err error) {
	bs.mu.Lock()
	defer bs.mu.Unlock()

	if bs.failed != nil {
		return
	}

	if err == nil {
		bs.failed = io.EOF
	} else {
		bs.failed = err
	}
	close(bs.closed)
}

// Err returns nill or an error when processing fails or the context was canceled
func (bs *ByteSource) Err() error {
	bs.mu.Lock()
	defer bs.mu.Unlock()

	if errors.Is(bs.failed, io.EOF) || errors.Is(bs.failed, context.Canceled) {
		return nil
	}

	return bs.failed
}

// Next blocks until there are new muxrpc frames for this stream
func (bs *ByteSource) Next(ctx context.Context) bool {
	bs.mu.Lock()
	if bs.failed != nil && bs.buf.frames == 0 {
		// don't return buffer before stream is empty
		// TODO: what if a stream isn't fully drained?!
		bs.bpool.Put(bs.buf.store)
		bs.mu.Unlock()
		return false
	}
	if bs.buf.frames > 0 {
		bs.mu.Unlock()
		return true
	}
	bs.mu.Unlock()

	select {
	case <-bs.streamCtx.Done():
		bs.mu.Lock()
		defer bs.mu.Unlock()
		if bs.failed == nil {
			bs.failed = bs.streamCtx.Err()
		}
		return bs.buf.Frames() > 0

	case <-ctx.Done():
		bs.mu.Lock()
		defer bs.mu.Unlock()
		if bs.failed == nil {
			bs.failed = ctx.Err()
		}
		return false

	case <-bs.closed:
		return bs.buf.Frames() > 0

	case <-bs.buf.waitForMore():
		return true
	}
}

// Reader passes a (limited) reader for the next segment to the passed .
// Since the stream can't be written while it's read, the reader is only valid during the call to the passed function.
func (bs *ByteSource) Reader(fn ReadFn) error {
	_, rd, err := bs.buf.getNextFrameReader()
	if err != nil {
		return err
	}

	bs.buf.mu.Lock()
	err = fn(rd)
	bs.buf.mu.Unlock()
	return err
}

// Bytes returns the full slice of bytes from the next frame.
func (bs *ByteSource) Bytes() ([]byte, error) {
	_, rd, err := bs.buf.getNextFrameReader()
	if err != nil {
		return nil, err
	}
	bs.buf.mu.Lock()
	b, err := ioutil.ReadAll(rd)
	bs.buf.mu.Unlock()
	return b, err
}

func (bs *ByteSource) consume(pktLen uint32, flag codec.Flag, r io.Reader) error {
	bs.mu.Lock()
	defer bs.mu.Unlock()

	if bs.failed != nil {
		return fmt.Errorf("muxrpc: byte source canceled: %w", bs.failed)
	}

	bs.hdrFlag = flag

	err := bs.buf.copyBody(pktLen, r)
	if err != nil {
		return err
	}

	return nil
}

// utils

// frame buffer: a buffer frames and a frame is length+body.
// it stores muxrpc body packets with their length as one contiguous stream in a bytes.Buffer
type frameBuffer struct {
	mu    sync.Mutex
	store *bytes.Buffer

	// TODO[weird-chans]: why exactly do you need a list of channels here
	waiting []chan<- struct{}

	// how much of the current frame has been read
	// to advance/skip store correctly
	currentFrameTotal uint32
	currentFrameRead  uint32

	frames uint32

	lenBuf [4]byte
}

func (fb *frameBuffer) Frames() uint32 {
	return atomic.LoadUint32(&fb.frames)
}

func (fb *frameBuffer) copyBody(pktLen uint32, rd io.Reader) error {
	fb.mu.Lock()
	defer fb.mu.Unlock()

	binary.LittleEndian.PutUint32(fb.lenBuf[:], uint32(pktLen))
	fb.store.Write(fb.lenBuf[:])

	copied, err := io.Copy(fb.store, rd)
	if err != nil {
		return err
	}

	if uint32(copied) != pktLen {
		return errors.New("frameBuffer: failed to consume whole body")
	}

	atomic.AddUint32(&fb.frames, 1)

	// TODO[weird-chans]: why exactly do you need a list of channels here
	if n := len(fb.waiting); n > 0 {
		for _, ch := range fb.waiting {
			close(ch)
		}
		fb.waiting = make([]chan<- struct{}, 0)
	}
	return nil
}

func (fb *frameBuffer) waitForMore() <-chan struct{} {
	fb.mu.Lock()
	defer fb.mu.Unlock()

	// TODO: maybe retrn nil to signal this instead of allocating channels that are immediatly closed?
	ch := make(chan struct{})
	if fb.frames > 0 {
		close(ch)
		return ch
	}

	// TODO[weird-chans]: why exactly do you need a list of channels here
	fb.waiting = append(fb.waiting, ch)
	return ch
}

func (fb *frameBuffer) getNextFrameReader() (uint32, io.Reader, error) {
	fb.mu.Lock()
	defer fb.mu.Unlock()

	if fb.currentFrameTotal != 0 {
		// if the last frame hasn't been fully read
		diff := int64(fb.currentFrameTotal - fb.currentFrameRead)
		if diff > 0 {
			// seek it into /dev/null
			io.Copy(ioutil.Discard, io.LimitReader(fb.store, diff))
		}
	}

	_, err := fb.store.Read(fb.lenBuf[:])
	if err != nil {
		return 0, nil, fmt.Errorf("muxrpc: didnt get length of next body (frames:%d): %w", fb.frames, err)
	}
	pktLen := binary.LittleEndian.Uint32(fb.lenBuf[:])

	fb.currentFrameRead = 0
	fb.currentFrameTotal = pktLen

	rd := &countingReader{
		rd:   io.LimitReader(fb.store, int64(pktLen)),
		read: &fb.currentFrameRead,
	}

	// fb.frames--
	atomic.AddUint32(&fb.frames, ^uint32(0))
	return pktLen, rd, nil
}

type countingReader struct {
	rd io.Reader

	read *uint32
}

func (cr *countingReader) Read(b []byte) (int, error) {
	n, err := cr.rd.Read(b)
	if err == nil && n > 0 {
		*cr.read += uint32(n)
	}
	return n, err
}
