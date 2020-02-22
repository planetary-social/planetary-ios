// SPDX-License-Identifier: MIT

package repo

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"regexp"

	"github.com/dgraph-io/badger"
	_ "github.com/mattn/go-sqlite3"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	libmkv "go.cryptoscope.co/librarian/mkv"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/codec/msgpack"
	"go.cryptoscope.co/margaret/multilog"
	multibadger "go.cryptoscope.co/margaret/multilog/badger"
	"go.cryptoscope.co/margaret/multilog/roaringfiles"
	"modernc.org/kv"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
)

var _ Interface = repo{}

// New creates a new repository value, it opens the keypair and database from basePath if it is already existing
func New(basePath string) Interface {
	return repo{basePath: basePath}
}

type repo struct {
	basePath string
}

func (r repo) GetPath(rel ...string) string {
	return filepath.Join(append([]string{r.basePath}, rel...)...)
}

const PrefixMultiLog = "sublogs"

type ServeFunc func(context.Context, margaret.Log, bool) error

// OpenBadgerMultiLog uses the repo to determine the paths where to finds the multilog with given name and opens it.
//
// Exposes the badger db for 100% hackability. This will go away in future versions!
// badger + librarian as index
func OpenBadgerMultiLog(r Interface, name string, f multilog.Func) (multilog.MultiLog, ServeFunc, error) {

	dbPath := r.GetPath(PrefixMultiLog, name, "db")
	err := os.MkdirAll(dbPath, 0700)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "mkdir error for %q", dbPath)
	}

	db, err := badger.Open(badgerOpts(dbPath))
	if err != nil {
		return nil, nil, errors.Wrap(err, "db/idx: badger failed to open")
	}

	mlog := multibadger.New(db, msgpack.New(margaret.BaseSeq(0)))

	statePath := r.GetPath(PrefixMultiLog, name, "state.json")
	mode := os.O_RDWR | os.O_EXCL
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		mode |= os.O_CREATE
	}
	idxStateFile, err := os.OpenFile(statePath, mode, 0700)
	if err != nil {
		return nil, nil, errors.Wrap(err, "error opening state file")
	}

	mlogSink := multilog.NewSink(idxStateFile, mlog, f)

	serve := func(ctx context.Context, rootLog margaret.Log, live bool) error {
		if rootLog == nil {
			return errors.Errorf("repo/multilog: %s was passed a nil root log", name)
		}

		src, err := rootLog.Query(margaret.Live(live), margaret.SeqWrap(true), mlogSink.QuerySpec())
		if err != nil {
			return errors.Wrap(err, "error querying rootLog for mlog")
		}

		err = luigi.Pump(ctx, mlogSink, src)
		if err == ssb.ErrShuttingDown {
			return nil
		}

		return errors.Wrap(err, "error reading query for mlog")
	}

	return mlog, serve, nil
}

func OpenMultiLog(r Interface, name string, f multilog.Func) (multilog.MultiLog, ServeFunc, error) {

	dbPath := r.GetPath(PrefixMultiLog, name, "roaring")
	err := os.MkdirAll(dbPath, 0700)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "mkdir error for %q", dbPath)
	}

	mkvPath := filepath.Join(dbPath, "mkv")
	mlog, err := roaringfiles.NewMKV(mkvPath)
	if err != nil {
		// yuk..
		if !isLockFileExistsErr(err) {
			return nil, nil, errors.Wrapf(err, "failed to recover lockfiles")
		}
		if err := cleanupLockFiles(dbPath); err != nil {
			return nil, nil, errors.Wrapf(err, "failed to recover lockfiles")

		}
		mlog, err = roaringfiles.NewMKV(mkvPath)
		if err != nil {
			return nil, nil, errors.Wrapf(err, "failed to open roaring db")
		}
	}

	if err := mlog.CompressAll(); err != nil {
		return nil, nil, errors.Wrapf(err, "failed to compress db")
	}

	// todo: save the current state in the multilog
	statePath := r.GetPath(PrefixMultiLog, name, "state_mkv.json")
	mode := os.O_RDWR | os.O_EXCL
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		mode |= os.O_CREATE
	}
	idxStateFile, err := os.OpenFile(statePath, mode, 0700)
	if err != nil {
		return nil, nil, errors.Wrap(err, "error opening state file")
	}

	mlogSink := multilog.NewSink(idxStateFile, mlog, f)

	serve := func(ctx context.Context, rootLog margaret.Log, live bool) error {
		if rootLog == nil {
			return errors.Errorf("repo/multilog: %s was passed a nil root log", name)
		}

		src, err := rootLog.Query(margaret.Live(live), margaret.SeqWrap(true), mlogSink.QuerySpec())
		if err != nil {
			return errors.Wrap(err, "error querying rootLog for mlog")
		}

		err = luigi.Pump(ctx, mlogSink, src)
		if err == ssb.ErrShuttingDown || errors.Cause(err) == context.Canceled {
			return nil
		}

		return errors.Wrap(err, "error reading query for mlog")
	}

	return mlog, serve, nil
}

func cleanupLockFiles(root string) error {
	return filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		name := filepath.Base(path)
		if info.Size() == 0 && len(name) == 41 && name[0] == '.' {
			log.Println("dropping empty lockflile", path)
			if err := os.Remove(path); err != nil {
				return errors.Wrapf(err, "failed to remove %s", name)
			}
		}
		return nil
	})
}

const PrefixIndex = "indexes"

func OpenIndex(r Interface, name string, f func(librarian.SeqSetterIndex) librarian.SinkIndex) (librarian.Index, ServeFunc, error) {
	pth := r.GetPath(PrefixIndex, name, "mkv")
	err := os.MkdirAll(pth, 0700)
	if err != nil {
		return nil, nil, errors.Wrap(err, "error making index directory")
	}

	opts := &kv.Options{}
	dbname := filepath.Join(pth, "idx.mkv")
	var db *kv.DB
	_, err = os.Stat(dbname)
	if os.IsNotExist(err) {
		db, err = kv.Create(dbname, opts)
		if err != nil {
			return nil, nil, errors.Wrap(err, "failed to create mkv")
		}
	} else if err != nil {
		return nil, nil, errors.Wrap(err, "failed to stat path location")
	} else {
		db, err = kv.Open(dbname, opts)
		if err != nil {

			if !isLockFileExistsErr(err) {
				return nil, nil, err
			}
			if err := cleanupLockFiles(pth); err != nil {
				return nil, nil, errors.Wrapf(err, "failed to recover lockfiles")
			}
			db, err = kv.Open(dbname, opts)
			if err != nil {
				return nil, nil, errors.Wrap(err, "failed to open mkv")
			}
		}
	}

	idx := libmkv.NewIndex(db, margaret.BaseSeq(0))
	sinkidx := f(idx)

	serve := func(ctx context.Context, rootLog margaret.Log, live bool) error {
		src, err := rootLog.Query(margaret.Live(live), margaret.SeqWrap(true), sinkidx.QuerySpec())
		if err != nil {
			return errors.Wrap(err, "error querying root log")
		}

		err = luigi.Pump(ctx, sinkidx, src)
		if err == ssb.ErrShuttingDown || errors.Cause(err) == context.Canceled {
			return db.Close()
		}

		return errors.Wrap(err, "contacts index pump failed")
	}

	return idx, serve, nil
}

func OpenBadgerIndex(r Interface, name string, f func(*badger.DB) librarian.SinkIndex) (*badger.DB, librarian.SinkIndex, ServeFunc, error) {
	pth := r.GetPath(PrefixIndex, name, "db")
	err := os.MkdirAll(pth, 0700)
	if err != nil {
		return nil, nil, nil, errors.Wrap(err, "error making index directory")
	}

	db, err := badger.Open(badgerOpts(pth))
	if err != nil {
		return nil, nil, nil, errors.Wrap(err, "db/idx: badger failed to open")
	}

	sinkidx := f(db)

	serve := func(ctx context.Context, rootLog margaret.Log, live bool) error {
		src, err := rootLog.Query(margaret.Live(live), margaret.SeqWrap(true), sinkidx.QuerySpec())
		if err != nil {
			return errors.Wrap(err, "error querying root log")
		}

		err = luigi.Pump(ctx, sinkidx, src)
		if err == ssb.ErrShuttingDown || errors.Cause(err) == context.Canceled {
			return nil
		}

		return errors.Wrap(err, "contacts index pump failed")
	}

	return db, sinkidx, serve, nil
}

func OpenBlobStore(r Interface) (ssb.BlobStore, error) {
	bs, err := blobstore.New(r.GetPath("blobs"))
	return bs, errors.Wrap(err, "error opening blob store")
}

var lockFileExistsRe = regexp.MustCompile(`cannot access DB \"(.*)\": lock file \"(.*)\" exists`)

func isLockFileExistsErr(err error) bool {
	log.Println("TODO: check process isn't running")
	if err == nil {
		return false
	}
	errStr := errors.Cause(err).Error()
	if !lockFileExistsRe.MatchString(errStr) {
		return false
	}
	matches := lockFileExistsRe.FindStringSubmatch(errStr)
	if len(matches) == 3 {
		return true
	}
	return false
}
