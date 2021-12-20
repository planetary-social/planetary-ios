// SPDX-License-Identifier: MIT

package offset2

import (
	"encoding/binary"
	"fmt"
	"io"
	"os"

	"go.cryptoscope.co/margaret"
)

type offset struct {
	*os.File
}

func (o *offset) readOffset(seq int64) (int64, error) {
	_, err := o.Seek(int64(seq)*8, io.SeekStart)
	if err != nil {
		return -1, fmt.Errorf("seek failed:%w", err)
	}

	var ofst int64
	err = binary.Read(o, binary.BigEndian, &ofst)
	if err != nil {
		return -1, fmt.Errorf("error reading offset %d: %w", seq, err)
	}
	return ofst, nil
}

func (o *offset) readLastOffset() (int64, int64, error) {
	stat, err := o.Stat()
	if err != nil {
		return 0, margaret.SeqEmpty, fmt.Errorf("stat failed:%w", err)
	}

	sz := stat.Size()
	if sz == 0 {
		return 0, margaret.SeqEmpty, nil
	}

	// this should be off-by-one-error-free:
	// sz is 8 when there is one entry, and the first entry has seq 0
	seqOfst := int64(sz/8 - 1)

	var ofstData int64
	err = binary.Read(io.NewSectionReader(o, sz-8, 8), binary.BigEndian, &ofstData)
	if err != nil {
		return 0, margaret.SeqEmpty, fmt.Errorf("error reading entry:%w", err)
	}

	return ofstData, seqOfst, nil
}

func (o *offset) append(ofst int64) (int64, error) {
	ofstOfst, err := o.Seek(0, io.SeekEnd)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("could not seek to end of file:%w", err)
	}
	seq := int64(ofstOfst / 8)

	err = binary.Write(o, binary.BigEndian, ofst)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("error writing offset:%w", err)
	}
	return seq, nil
}
