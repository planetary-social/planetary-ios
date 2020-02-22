// SPDX-License-Identifier: MIT

package offset2

import (
	"encoding/binary"
	"io"
	"os"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
)

type offset struct {
	*os.File
}

func (o *offset) readOffset(seq margaret.Seq) (int64, error) {
	_, err := o.Seek(seq.Seq()*8, io.SeekStart)
	if err != nil {
		return 0, errors.Wrap(err, "seek failed")
	}

	var ofst int64
	err = binary.Read(o, binary.BigEndian, &ofst)
	return ofst, errors.Wrap(err, "error reading offset")
}

func (o *offset) readLastOffset() (int64, margaret.Seq, error) {
	stat, err := o.Stat()
	if err != nil {
		return 0, margaret.SeqEmpty, errors.Wrap(err, "stat failed")
	}

	sz := stat.Size()
	if sz == 0 {
		return 0, margaret.SeqEmpty, nil
	}

	// this should be off-by-one-error-free:
	// sz is 8 when there is one entry, and the first entry has seq 0
	seqOfst := margaret.BaseSeq(sz/8 - 1)

	var ofstData int64
	err = binary.Read(io.NewSectionReader(o, sz-8, 8), binary.BigEndian, &ofstData)
	if err != nil {
		return 0, margaret.SeqEmpty, errors.Wrap(err, "error reading entry")
	}

	return ofstData, seqOfst, nil
}

func (o *offset) append(ofst int64) (margaret.Seq, error) {
	ofstOfst, err := o.Seek(0, io.SeekEnd)
	seq := margaret.BaseSeq(ofstOfst / 8)
	if err != nil {
		return seq, errors.Wrap(err, "could not seek to end of file")
	}

	err = binary.Write(o, binary.BigEndian, ofst)
	return seq, errors.Wrap(err, "error writing offset")
}
