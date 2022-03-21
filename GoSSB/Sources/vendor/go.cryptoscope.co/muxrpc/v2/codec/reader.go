// SPDX-License-Identifier: MIT

package codec

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
)

type Reader struct{ r io.Reader }

func NewReader(r io.Reader) *Reader { return &Reader{r} }

// ReadPacket decodes the header from the underlying reader, and reads as many bytes as specified in it
// TODO: pass in packet pointer as arg to reduce allocations
func (r Reader) ReadPacket() (*Packet, error) {
	var hdr Header
	err := r.ReadHeader(&hdr)
	if err != nil {
		return nil, err
	}

	// copy header info
	var p = Packet{
		Flag: hdr.Flag,
		Req:  hdr.Req,
		Body: make([]byte, hdr.Len), // yiiikes! lot's of single-use allocations
	}

	_, err = io.ReadFull(r.r, p.Body)
	if err != nil {
		if errors.Is(err, os.ErrClosed) || errors.Is(err, io.EOF) || errors.Is(err, io.ErrClosedPipe) {
			return nil, err
		}
		return nil, fmt.Errorf("pkt-codec: read body failed: %w", err)
	}

	return &p, nil
}

// ReadHeader only reads the header packet data (flag, len, req id). Use the exposed io.Reader to read the body.
func (r Reader) ReadHeader(hdr *Header) error {
	err := binary.Read(r.r, binary.BigEndian, hdr)
	if err != nil {
		if errors.Is(err, os.ErrClosed) || errors.Is(err, io.EOF) || errors.Is(err, io.ErrClosedPipe) {
			return io.EOF
		}
		return fmt.Errorf("pkt-codec: header read failed: %w", err)
	}

	// detect EOF pkt
	if hdr.Flag == 0 && hdr.Len == 0 && hdr.Req == 0 {
		return io.EOF
	}
	return nil
}

func (r Reader) NextBodyReader(pktLen uint32) io.Reader {
	return io.LimitReader(r.r, int64(pktLen))
}

func (r Reader) ReadBodyInto(w io.Writer, pktLen uint32) error {
	n, err := io.Copy(w, r.NextBodyReader(pktLen))
	if err != nil {
		return fmt.Errorf("pkt-codec: failed to read full body: %w", err)
	}

	if uint32(n) != pktLen {
		return errors.New("pkt-codec: failed to read full body")
	}

	return nil
}
