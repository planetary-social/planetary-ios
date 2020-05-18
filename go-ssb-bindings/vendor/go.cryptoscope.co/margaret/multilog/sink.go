// SPDX-License-Identifier: MIT

package multilog

import (
	"context"
	"io"
	"os"
	"sync"

	"github.com/keks/persist"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"
)

// Func is a processing function that consumes a stream and sets values in the multilog.
type Func func(ctx context.Context, seq margaret.Seq, value interface{}, mlog MultiLog) error

// Sink is both a multilog and a luigi sink. Pouring values into it will append values to the multilog, usually by calling a user-defined processing function.
type Sink interface {
	MultiLog
	Pour(ctx context.Context, v interface{}) error
	QuerySpec() margaret.QuerySpec
}

// NewSink makes a new Sink by wrapping a MultiLog and a processing function of type Func.
func NewSink(file *os.File, mlog MultiLog, f Func) Sink {
	return &sinkLog{
		mlog: mlog,
		f:    f,
		file: file,
		l:    &sync.Mutex{},
	}
}

type sinkLog struct {
	mlog MultiLog
	f    Func
	file *os.File
	l    *sync.Mutex
}

// Get gets the sublog with the given address.
func (slog *sinkLog) Get(addr librarian.Addr) (margaret.Log, error) {
	log, err := slog.mlog.Get(addr)
	if err != nil {
		return nil, errors.Wrap(err, "error getting log from multilog")
	}

	return roLog{log}, nil
}

// List returns the addresses of all sublogs in the multilog
func (slog *sinkLog) List() ([]librarian.Addr, error) {
	return slog.mlog.List()
}

func (slog *sinkLog) Delete(addr librarian.Addr) error {
	return slog.mlog.Delete(addr)
}

// Pour calls the processing function to add a value to a sublog.
func (slog *sinkLog) Pour(ctx context.Context, v interface{}) error {
	slog.l.Lock()
	defer slog.l.Unlock()

	seq := v.(margaret.SeqWrapper)
	err := persist.Save(slog.file, seq.Seq())
	if err != nil {
		return errors.Wrap(err, "error saving current sequence number")
	}

	err = slog.f(ctx, seq.Seq(), seq.Value(), slog.mlog)
	return errors.Wrap(err, "multilog/sink: error in processing function")
}

func (slog *sinkLog) Flush() error { return slog.mlog.Flush() }

// Close does nothing.
func (slog *sinkLog) Close() error { return nil }

// QuerySpec returns the query spec that queries the next needed messages from the log
func (slog *sinkLog) QuerySpec() margaret.QuerySpec {
	slog.l.Lock()
	defer slog.l.Unlock()

	var seq margaret.BaseSeq

	if err := persist.Load(slog.file, &seq); err != nil {
		if errors.Cause(err) != io.EOF {
			return margaret.ErrorQuerySpec(err)
		}

		seq = margaret.SeqEmpty
	}

	return margaret.MergeQuerySpec(
		margaret.Gt(seq),
		margaret.SeqWrap(true),
	)
}

type roLog struct {
	margaret.Log
}

// Append always returns an error that indicates that this log is read only.
func (roLog) Append(v interface{}) (margaret.Seq, error) {
	return margaret.SeqEmpty, errors.New("can't append to read-only log")
}
