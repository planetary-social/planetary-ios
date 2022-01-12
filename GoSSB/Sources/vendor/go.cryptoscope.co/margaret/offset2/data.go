// SPDX-License-Identifier: MIT

package offset2

import (
	"bytes"
	"encoding/binary"
	"io"
	"os"

	"github.com/pkg/errors"
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
		return nil, errors.Wrap(err, "error reading payload length")
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
		return 0, errors.Wrap(err, "error reading payload length")
	}

	return d.ReadAt(data, ofst+8)
}

func (d *data) getFrameSize(ofst int64) (int64, error) {
	_, err := d.ReadAt(d.buf[:], ofst)
	if err != nil {
		return 0, errors.Wrap(err, "error reading payload length")
	}

	buf := bytes.NewBuffer(d.buf[:])

	var sz int64
	err = binary.Read(buf, binary.BigEndian, &sz)
	return sz, errors.Wrap(err, "error parsing payload length")
}

func (d *data) getFrame(ofst int64) ([]byte, error) {
	sz, err := d.getFrameSize(ofst)
	if err != nil {
		return nil, errors.Wrap(err, "error getting frame size")
	}

	data := make([]byte, sz)
	_, err = d.readFrame(data, ofst)
	return data, errors.Wrap(err, "error reading frame")
}

func (d *data) append(data []byte) (int64, error) {
	ofst, err := d.Seek(0, io.SeekEnd)
	if err != nil {
		return 0, errors.Wrap(err, "failed to seek to end of file")
	}

	err = binary.Write(d, binary.BigEndian, int64(len(data)))
	if err != nil {
		return 0, errors.Wrap(err, "writing length prefix failed")
	}

	_, err = d.Write(data)
	return ofst, errors.Wrap(err, "error writing data")
}
