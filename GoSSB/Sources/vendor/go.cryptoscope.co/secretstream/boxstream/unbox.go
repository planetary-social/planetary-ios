// SPDX-License-Identifier: MIT

package boxstream

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"

	"golang.org/x/crypto/nacl/secretbox"
)

// Unboxer decrypts everything that is read from it
type Unboxer struct {
	r      io.Reader
	buf    [MaxSegmentSize + secretbox.Overhead]byte
	secret *[32]byte
	nonce  *[24]byte
}

// ReadMessage reads the next message from the underlying stream. If the next
// message was a 'goodbye', it returns io.EOF.
func (u *Unboxer) ReadMessage() ([]byte, error) {
	headerNonce := *u.nonce
	increment(u.nonce)
	bodyNonce := *u.nonce
	increment(u.nonce)

	// read and unbox header
	headerBox := u.buf[:HeaderLength]
	if _, err := io.ReadFull(u.r, headerBox); err != nil {
		return nil, err
	}
	headerBuf := make([]byte, 0, 18)
	header, ok := secretbox.Open(headerBuf, headerBox, &headerNonce, u.secret)
	if !ok {
		return nil, errors.New("invalid header box")
	}

	// zero header indicates termination
	if bytes.Equal(header, goodbye[:]) {
		return nil, io.EOF
	}

	// read and unbox body
	bodyLen := binary.BigEndian.Uint16(header[:2])
	if bodyLen > MaxSegmentSize {
		return nil, errors.New("message exceeds maximum segment size")
	}
	bodyBox := u.buf[:bodyLen+secretbox.Overhead]
	if _, err := io.ReadFull(u.r, bodyBox[secretbox.Overhead:]); err != nil {
		return nil, err
	}
	// prepend with MAC from header
	copy(bodyBox, header[2:])
	msg, ok := secretbox.Open(nil, bodyBox, &bodyNonce, u.secret)
	if !ok {
		return nil, errors.New("invalid body box")
	}
	return msg, nil
}

// NewUnboxer wraps the passed Reader into an Unboxer.
func NewUnboxer(r io.Reader, nonce *[24]byte, secret *[32]byte) *Unboxer {
	return &Unboxer{
		r:      r,
		secret: secret,
		nonce:  nonce,
	}
}
