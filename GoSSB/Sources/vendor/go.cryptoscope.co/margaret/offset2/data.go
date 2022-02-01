// SPDX-License-Identifier: MIT

package offset2

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"

	"go.cryptoscope.co/margaret"
)

type data struct {
	*os.File

	buf [8]byte
}

func (d *data) frameReader(ofst int64) (io.Reader, error) {
	var sz int64
	err := binary.Read(io.NewSectionReader(d, ofst, 8), binary.BigEndian, &sz)
	if err != nil {
		return nil, fmt.Errorf("error reading payload length: %w", err)
	}

	if sz < 0 {
		return nil, margaret.ErrNulled
	}

	return io.NewSectionReader(d, ofst+8, sz), nil
}

func (d *data) readFrame(data []byte, ofst int64) (int, error) {
	sr := io.NewSectionReader(d, ofst, 8)

	var sz int64
	err := binary.Read(sr, binary.BigEndian, &sz)
	if err != nil {
		return 0, fmt.Errorf("error reading payload length: %w", err)
	}

	return d.ReadAt(data, ofst+8)
}

func (d *data) getFrameSize(ofst int64) (int64, error) {
	_, err := d.ReadAt(d.buf[:], ofst)
	if err != nil {
		return -1, fmt.Errorf("error reading payload length: %w", err)
	}

	buf := bytes.NewBuffer(d.buf[:])

	var sz int64
	err = binary.Read(buf, binary.BigEndian, &sz)
	if err != nil {
		return -1, fmt.Errorf("error parsing payload length: %w", err)
	}

	return sz, nil
}

func (d *data) getFrame(ofst int64) ([]byte, error) {
	sz, err := d.getFrameSize(ofst)
	if err != nil {
		return nil, fmt.Errorf("error getting frame size: %w", err)
	}

	data := make([]byte, sz)
	_, err = d.readFrame(data, ofst)
	if err != nil {
		return nil, fmt.Errorf("error reading frame: %w", err)
	}
	return data, nil
}

func (d *data) append(data []byte) (int64, error) {
	ofst, err := d.Seek(0, io.SeekEnd)
	if err != nil {
		return -1, fmt.Errorf("failed to seek to end of file: %w", err)
	}

	err = binary.Write(d, binary.BigEndian, int64(len(data)))
	if err != nil {
		return -1, fmt.Errorf("writing length prefix failed: %w", err)
	}

	_, err = d.Write(data)
	if err != nil {
		return -1, fmt.Errorf("error writing data: %w", err)
	}
	return ofst, nil
}
