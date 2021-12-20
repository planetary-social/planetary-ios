// SPDX-License-Identifier: MIT

/*Package offset2 implements a margaret log as persisted sequence of data across multiple files.

Format Defintion

A log consists of three files: data, ofst and jrnl.

* data: a list of length-prefixed data chunks, size is a uint64 (size++[size]byte).

* ofst: a list of uint64, representing entry offsets in 'data'

* jrnl keeps track of the current sequence number, see checkJournal() for more

To read entry 5 in `data`, you follow these steps:

1. Seek to 5*(sizeof(uint64)=8)=40 in `ofset` and read the uint64 representing the offset in `data`

2. Seek to that offset in `data`, read the length-prefix (the uint64 for the size of the entry)

3. Finally, read that amount of data, which is your entry

All uint64's are encoded in BigEndian.

*/
package offset2

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
)

type offsetLog struct {
	l    sync.Mutex
	name string

	jrnl *journal
	ofst *offset
	data *data

	seqCurrent int64
	seqChanges luigi.Observable

	codec margaret.Codec

	bcast  luigi.Broadcast
	bcSink luigi.Sink
}

func (log *offsetLog) Close() error {
	// TODO: close open querys?
	// log.l.Lock()
	// defer log.l.Unlock()

	if err := log.jrnl.Close(); err != nil {
		return fmt.Errorf("journal file close failed: %w", err)
	}

	if err := log.ofst.Close(); err != nil {
		return fmt.Errorf("offset file close failed: %w", err)
	}

	if err := log.data.Close(); err != nil {
		return fmt.Errorf("data file close failed: %w", err)
	}

	if err := log.bcSink.Close(); err != nil {
		return fmt.Errorf("log broadcast close failed: %w", err)
	}

	return nil
}

var _ margaret.Alterer = (*offsetLog)(nil)

// Null overwrites the entry at seq with zeros
// updating is kinda odd in append-only
// but in some cases you still might want to redact entries
func (log *offsetLog) Null(seq int64) error {

	log.l.Lock()
	defer log.l.Unlock()

	ofst, err := log.ofst.readOffset(seq)
	if err != nil {
		return fmt.Errorf("null: error read offset: %w", err)
	}

	sz, err := log.data.getFrameSize(ofst)
	if err != nil {
		return fmt.Errorf("null: get frame size failed: %w", err)
	}

	if sz < 0 { // entry already nulled
		return nil
	}

	var minusSz bytes.Buffer
	err = binary.Write(&minusSz, binary.BigEndian, -sz)
	if err != nil {
		return fmt.Errorf("null: failed to encode neg size: %d: %w", -sz, err)
	}

	_, err = log.data.WriteAt(minusSz.Bytes(), ofst)
	if err != nil {
		return fmt.Errorf("null: failed to write -1 size bytes at %d: %w", ofst, err)
	}

	nulls := make([]byte, sz)
	_, err = log.data.WriteAt(nulls, ofst+8)
	if err != nil {
		return fmt.Errorf("null: failed to write %d bytes at %d: %w", sz, ofst, err)
	}

	return nil
}

// Replace overwrites the seq entry with data.
// data has to be smaller then the current entry.
func (log *offsetLog) Replace(seq int64, data []byte) error {
	log.l.Lock()
	defer log.l.Unlock()

	ofst, err := log.ofst.readOffset(seq)
	if err != nil {
		return fmt.Errorf("offset2/replace: error read offset: %w", err)
	}

	sz, err := log.data.getFrameSize(ofst)
	if err != nil {
		return fmt.Errorf("offset2/replace: get frame size failed: %w", err)
	}

	newSz := int64(len(data))
	if sz < newSz {
		return fmt.Errorf("offset2/replace: can't overwrite entry with larger data (diff:%d)", newSz-sz)
	}

	nulls := make([]byte, sz)
	copy(nulls[:], data)

	_, err = log.data.WriteAt(nulls, ofst+8)
	if err != nil {
		return fmt.Errorf("offset2/replace: null: failed to write %d bytes at %d: %w", sz, ofst, err)
	}

	return nil
}

// Open returns a the offset log in the directory at `name`.
// If it is empty or does not exist, a new log will be created.
func Open(name string, cdc margaret.Codec) (*offsetLog, error) {
	err := os.MkdirAll(name, 0700)
	if err != nil {
		return nil, fmt.Errorf("offset2: error making log directory at %q: %w", name, err)
	}

	pLog := filepath.Join(name, "data")
	fData, err := os.OpenFile(pLog, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, fmt.Errorf("offset2: error opening log data file at %q: %w", pLog, err)
	}

	pOfst := filepath.Join(name, "ofst")
	fOfst, err := os.OpenFile(pOfst, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, fmt.Errorf("offset2: error opening log offset file at %q: %w", pOfst, err)
	}

	pJrnl := filepath.Join(name, "jrnl")
	fJrnl, err := os.OpenFile(pJrnl, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, fmt.Errorf("offset2: error opening log journal file at %q: %w", pJrnl, err)
	}

	log := &offsetLog{
		name: name,

		jrnl: &journal{fJrnl},
		ofst: &offset{fOfst},
		data: &data{File: fData},

		codec: cdc,
	}

	_, err = log.checkJournal()
	if err != nil {
		return nil, fmt.Errorf("offset2: integrity error: %w", err)
	}

	log.bcSink, log.bcast = luigi.NewBroadcast()

	// get current sequence by end / blocksize
	end, err := fOfst.Seek(0, io.SeekEnd)
	if err != nil {
		return nil, fmt.Errorf("offset2: failed to seek to end of log-offset-file: %w", err)
	}
	// assumes -1 is SeqEmpty
	log.seqCurrent = (end / 8) - 1
	log.seqChanges = luigi.NewObservable(log.seqCurrent)

	return log, nil
}

// checkJournal verifies that the last entry is consistent along the three files.
//  - read sequence from journal
//  - read last offset from offset file
//  - read frame size from data file at previously read offset
//  - check that the end of the frame is also end of file
//  - check that number of entries in offset file equals value in journal
func (log *offsetLog) checkJournal() (int64, error) {
	seqJrnl, err := log.jrnl.readSeq()
	if err != nil {
		return margaret.SeqErrored, fmt.Errorf("error reading seq: %w", err)
	}

	if seqJrnl == margaret.SeqEmpty {
		statOfst, err := log.ofst.Stat()
		if err != nil {
			return margaret.SeqErrored, fmt.Errorf("stat failed on offset file: %w", err)
		}

		if statOfst.Size() != 0 {
			return margaret.SeqErrored, errors.New("journal empty but offset file isnt")
		}

		statData, err := log.data.Stat()
		if err != nil {
			return margaret.SeqErrored, fmt.Errorf("stat failed on data file: %w", err)
		}

		if statData.Size() != 0 {
			return margaret.SeqErrored, errors.New("journal empty but data file isnt")
		}

		return margaret.SeqEmpty, nil
	}

	ofstData, seqOfst, err := log.ofst.readLastOffset()
	if err != nil {
		return margaret.SeqErrored, fmt.Errorf("error reading last entry of log offset file: %w", err)
	}

	diff := seqJrnl - seqOfst
	if diff != 0 {
		if diff < 0 { // more data then entries in journal (unclear how to handle)
			// TODO: chop of data and offset to min(journal,count(ofst))
			return margaret.SeqErrored, fmt.Errorf("seq in journal does not match element count in log offset file - %d != %d", seqJrnl, seqOfst)
		}

		// recover by truncating setting journal to count(ofst)
		_, err = log.jrnl.Seek(0, io.SeekStart)
		if err != nil {
			return margaret.SeqErrored, fmt.Errorf("recover: could not seek to start of journal file: %w", err)
		}

		err = binary.Write(log.jrnl, binary.BigEndian, seqOfst)
		if err != nil {
			return margaret.SeqErrored, fmt.Errorf("recover: could not overwrite journal with offset seq: %w", err)
		}

		if err := log.CheckConsistency(); err != nil {
			return margaret.SeqErrored, fmt.Errorf("recover: check journal 2nd pass: %w", err)
		}
	}

	sz, err := log.data.getFrameSize(ofstData)
	if err != nil {
		return margaret.SeqErrored, fmt.Errorf("error getting frame size from log data file: %w", err)
	}

	if sz < 0 { // entry nulled
		// irrelevant here, just treat the nulls as regular bytes
		sz = -sz
	}

	stat, err := log.data.Stat()
	if err != nil {
		return margaret.SeqErrored, fmt.Errorf("error stat'ing data file: %w", err)
	}

	n := ofstData + 8 + sz
	d := n - stat.Size()
	if d != 0 {
		// TODO: chop off the rest
		return margaret.SeqErrored, fmt.Errorf("data file size difference %d", d)
	}

	return seqJrnl, nil
}

// CheckConsistency is an fsck for the offset log.
func (log *offsetLog) CheckConsistency() error {
	_, err := log.checkJournal()
	if err != nil {
		return fmt.Errorf("offset2: journal inconsistent: %w", err)
	}

	var (
		ofst, nextOfst int64
		seq            int64
	)

	for {
		sz, err := log.data.getFrameSize(nextOfst)
		if errors.Is(err, io.EOF) {
			return nil
		} else if err != nil {
			return fmt.Errorf("error getting frame size: %w", err)
		}

		ofst = nextOfst

		if sz < 0 { // TODO: nulled with user flags
			sz = -sz
		}

		nextOfst += sz + 8 // 8 byte length prefix

		expOfst, err := log.ofst.readOffset(seq)
		if errors.Is(err, io.EOF) {
			return nil
		} else if err != nil {
			return fmt.Errorf("error reading expected offset: %w", err)
		}

		if ofst != expOfst {
			return fmt.Errorf("offset mismatch: offset file says %d, data file has %d", expOfst, ofst)
		}
		seq++
	}
}

func (log *offsetLog) Seq() int64 {
	log.l.Lock()
	defer log.l.Unlock()
	return log.seqCurrent
}

func (log *offsetLog) Changes() luigi.Observable {
	return log.seqChanges
}

func (log *offsetLog) Get(seq int64) (interface{}, error) {
	log.l.Lock()
	defer log.l.Unlock()

	v, err := log.readFrame(seq)
	if err != nil {
		if errors.Is(err, io.EOF) {
			return v, luigi.EOS{}
		}
		if errors.Is(err, margaret.ErrNulled) {
			return nil, margaret.ErrNulled
		}
		return nil, err
	}
	return v, nil
}

// readFrame reads and parses a frame.
func (log *offsetLog) readFrame(seq int64) (interface{}, error) {
	ofst, err := log.ofst.readOffset(seq)
	if err != nil {
		return nil, fmt.Errorf("error read offset of seq(%d): %w", seq, err)
	}

	r, err := log.data.frameReader(ofst)
	if err != nil {
		return nil, fmt.Errorf("error getting frame reader for seq(%d) (ofst:%d): %w", seq, ofst, err)
	}

	dec := log.codec.NewDecoder(r)
	v, err := dec.Decode()
	if err != nil {
		if errors.Is(err, io.EOF) {
			return v, luigi.EOS{}
		}
		return nil, fmt.Errorf("error decoding data for seq(%d) (ofst:%d): %w", seq, ofst, err)
	}
	return v, nil
}

func (log *offsetLog) Query(specs ...margaret.QuerySpec) (luigi.Source, error) {
	log.l.Lock()
	defer log.l.Unlock()

	qry := &offsetQuery{
		log:   log,
		codec: log.codec,

		nextSeq: margaret.SeqEmpty,
		lt:      margaret.SeqEmpty,

		limit: -1, //i.e. no limit
		close: make(chan struct{}),
	}

	for _, spec := range specs {
		err := spec(qry)
		if err != nil {
			return nil, err
		}
	}

	if qry.reverse && qry.live {
		return nil, fmt.Errorf("offset2: can't do reverse and live")
	}

	return qry, nil
}

func (log *offsetLog) Append(v interface{}) (int64, error) {
	data, err := log.codec.Marshal(v)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("offset2: error marshaling value: %w", err)
	}

	log.l.Lock()
	defer log.l.Unlock()

	jrnlSeq, err := log.jrnl.bump()
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("offset2: error bumping journal: %w", err)
	}

	ofst, err := log.data.append(data)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("offset2: error appending data: %w", err)
	}

	seq, err := log.ofst.append(ofst)
	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("offset2: error appending offset: %w", err)
	}

	if seq != jrnlSeq {
		return margaret.SeqEmpty, fmt.Errorf("offset2: seq mismatch: journal wants %d, offset has %d", jrnlSeq, seq)
	}

	err = log.bcSink.Pour(context.TODO(), margaret.WrapWithSeq(v, jrnlSeq))
	log.seqCurrent = seq
	log.seqChanges.Set(seq)

	if err != nil {
		return margaret.SeqEmpty, fmt.Errorf("offset2: error while updating registerd broadcasts with new value: %w", err)
	}

	return seq, nil
}

func (log *offsetLog) FileName() string {
	return log.name
}
