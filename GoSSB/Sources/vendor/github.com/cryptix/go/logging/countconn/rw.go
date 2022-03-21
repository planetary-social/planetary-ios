package countconn

import (
	"io"
	"sync/atomic"
)

// Reader counts the bytes read through it.
type Reader struct {
	r io.Reader
	n int64
}

// NewReader makes a new Reader that counts the bytes
// read through it.
func NewReader(r io.Reader) *Reader {
	return &Reader{
		r: r,
	}
}
func (r *Reader) Read(p []byte) (n int, err error) {
	n, err = r.r.Read(p)
	atomic.AddInt64(&r.n, int64(n))
	return
}

// N gets the number of bytes that have been read
// so far.
func (r *Reader) N() int64 {
	return atomic.LoadInt64(&r.n)
}

// Writer counts the bytes read through it.
type Writer struct {
	w io.Writer
	n int64
}

// NewWriter makes a new Writer that counts the bytes
// read through it.
func NewWriter(w io.Writer) *Writer {
	return &Writer{
		w: w,
	}
}
func (w *Writer) Write(p []byte) (n int, err error) {
	n, err = w.w.Write(p)
	atomic.AddInt64(&w.n, int64(n))
	return
}

// N gets the number of bytes that have been written
// so far.
func (w *Writer) N() int64 {
	return atomic.LoadInt64(&w.n)
}
