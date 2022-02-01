package repo

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/dgraph-io/badger/v3"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/margaret/multilog/roaring"
	multibadger "go.cryptoscope.co/margaret/multilog/roaring/badger"
	multifs "go.cryptoscope.co/margaret/multilog/roaring/fs"
)

// todo: save the current state in the multilog
func makeSinkIndex(dbPath string, mlog multilog.MultiLog, fn multilog.Func) (librarian.SinkIndex, error) {
	statePath := filepath.Join(dbPath, "..", "state.json")
	mode := os.O_RDWR | os.O_EXCL
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		mode |= os.O_CREATE
	}
	idxStateFile, err := os.OpenFile(statePath, mode, 0700)
	if err != nil {
		return nil, fmt.Errorf("error opening state file: %w", err)
	}

	return multilog.NewSink(idxStateFile, mlog, fn), nil
}

const PrefixMultiLog = "sublogs"

func OpenBadgerDB(path string) (*badger.DB, error) {
	opts := badgerOpts(path)
	return badger.Open(opts)
}

func OpenStandaloneMultiLog(r Interface, name string, f multilog.Func) (multilog.MultiLog, librarian.SinkIndex, error) {

	dbPath := r.GetPath(PrefixMultiLog, name, "badger")
	mlog, err := multibadger.NewStandalone(dbPath)
	if err != nil {
		return nil, nil, fmt.Errorf("mlog/badger: failed to open backing db: %w", err)
	}

	snk, err := makeSinkIndex(dbPath, mlog, f)
	if err != nil {
		return nil, nil, fmt.Errorf("mlog/badger: failed to create sink: %w", err)
	}

	return mlog, snk, nil
}

func OpenFileSystemMultiLog(r Interface, name string, f multilog.Func) (*roaring.MultiLog, librarian.SinkIndex, error) {
	dbPath := r.GetPath(PrefixMultiLog, name, "fs-bitmaps")
	err := os.MkdirAll(dbPath, 0700)
	if err != nil {
		return nil, nil, fmt.Errorf("mkdir error for %q: %w", dbPath, err)
	}

	mlog, err := multifs.NewMultiLog(dbPath)
	if err != nil {
		return nil, nil, fmt.Errorf("open error for %q: %w", dbPath, err)
	}

	snk, err := makeSinkIndex(dbPath, mlog, f)
	if err != nil {
		return nil, nil, fmt.Errorf("mlog/fs: failed to create sink: %w", err)
	}

	return mlog, snk, nil
}
