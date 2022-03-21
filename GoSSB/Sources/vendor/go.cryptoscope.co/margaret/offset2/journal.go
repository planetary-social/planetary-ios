// SPDX-FileCopyrightText: 2021 The margaret Authors
//
// SPDX-License-Identifier: MIT

package offset2

import (
	"encoding/binary"
	"fmt"
	"io"
	"os"

	"go.cryptoscope.co/margaret"
)

type journal struct {
	*os.File
}

func (j *journal) readSeq() (int64, error) {
	stat, err := j.Stat()
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("stat failed: %w", err)
	}

	switch sz := stat.Size(); sz {
	case 0:
		return margaret.SeqEmpty, nil
	case 8:
		// continue after switch
	default:
		return margaret.SeqEmpty, fmt.Errorf("expected file size of 8B, got %dB", sz)
	}

	_, err = j.Seek(0, io.SeekStart)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("could not seek to start of file: %w", err)
	}

	var seq int64
	err = binary.Read(j, binary.BigEndian, &seq)
	if err != nil {
		return margaret.SeqErrored, fmt.Errorf("error reading seq: %w", err)
	}
	return seq, nil
}

func (j *journal) bump() (int64, error) {
	seq, err := j.readSeq()
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("error reading old journal value: %w", err)
	}

	_, err = j.Seek(0, io.SeekStart)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("could not seek to start of file: %w", err)
	}

	seq = seq + 1
	err = binary.Write(j, binary.BigEndian, seq)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("error writing seq: %w", err)
	}

	return seq, nil
}
