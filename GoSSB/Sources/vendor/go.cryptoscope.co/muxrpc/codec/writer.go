// SPDX-License-Identifier: MIT

package codec

import (
	"encoding/binary"
	"io"
	"sync"

	"github.com/pkg/errors"
)

type Writer struct {
	sync.Mutex

	w io.Writer
}

// NewWriter creates a new packet-stream writer
func NewWriter(w io.Writer) *Writer { return &Writer{w: w} }

// WritePacket creates an header for the Packet and writes it and the body to the underlying writer
func (w *Writer) WritePacket(r *Packet) error {
	w.Lock()
	defer w.Unlock()
	hdr := Header{
		Flag: r.Flag,
		Len:  uint32(len(r.Body)),
		Req:  r.Req,
	}
	if err := binary.Write(w.w, binary.BigEndian, hdr); err != nil {
		return errors.Wrapf(err, "pkt-codec: header write failed")
	}
	if _, err := w.w.Write(r.Body); err != nil {
		return errors.Wrapf(err, "pkt-codec: body write failed")
	}
	return nil
}

// Close sends 9 zero bytes and also closes it's underlying writer if it is also an io.Closer
func (w *Writer) Close() error {
	w.Lock()
	defer w.Unlock()
	_, err := w.w.Write([]byte{0, 0, 0, 0, 0, 0, 0, 0, 0})
	if err != nil {
		return errors.Wrapf(err, "pkt-codec: failed to write Close() packet")
	}
	if c, ok := w.w.(io.Closer); ok {
		return errors.Wrap(c.Close(), "pkt-codec: failed to close underlying writer")
	}
	return nil
}
