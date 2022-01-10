// SPDX-License-Identifier: MIT

package offset2

import (
	"encoding/binary"
	"io"
	"os"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
)

type journal struct {
	*os.File
}

func (j *journal) readSeq() (margaret.Seq, error) {
	stat, err := j.Stat()
	if err != nil {
		return margaret.SeqEmpty, errors.Wrap(err, "stat failed")
	}

	switch sz := stat.Size(); sz {
	case 0:
		return margaret.SeqEmpty, nil
	case 8:
		// continue after switch
	default:
		return margaret.SeqEmpty, errors.Errorf("expected file size of 8B, got %dB", sz)
	}

	_, err = j.Seek(0, io.SeekStart)
	if err != nil {
		return margaret.SeqEmpty, errors.Wrap(err, "could not seek to start of file")
	}

	var seq margaret.BaseSeq
	err = binary.Read(j, binary.BigEndian, &seq)
	return seq, errors.Wrap(err, "error reading seq")
}

func (j *journal) bump() (margaret.Seq, error) {
	seq, err := j.readSeq()
	if err != nil {
		return margaret.SeqEmpty, errors.Wrap(err, "error reading old journal value")
	}

	_, err = j.Seek(0, io.SeekStart)
	if err != nil {
		return margaret.SeqEmpty, errors.Wrap(err, "could not seek to start of file")
	}

	seq = margaret.BaseSeq(seq.Seq() + 1)
	err = binary.Write(j, binary.BigEndian, seq)
	return seq, errors.Wrap(err, "error writing seq")
}
