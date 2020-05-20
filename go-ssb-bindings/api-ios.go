// Copyright (C) 2019 Henry Bubert <cryptix@riseup.net>. All Rights Reserved.

// scuttlebridge, makefile style
package main

// #include <stdlib.h>
// #include <sys/types.h>
// #include <stdint.h>
// #include <stdbool.h>
// static bool callBlobsNotify(void *func, int64_t size, const char *blobRef)
// {
//     return ((bool(*)(int64_t, const char *))func)(size, blobRef);
// }
import "C"

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	stderr "errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/cryptix/go/logging/countconn"
	kitlog "github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	_ "github.com/mattn/go-sqlite3"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/repo"
	"go.cryptoscope.co/ssb/repo/migrations"
	mksbot "go.cryptoscope.co/ssb/sbot"
)

var versionString *C.char

func init() {
	versionString = C.CString("beta1")
	log = kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stderr))
	log = kitlog.With(log, "warning", "pre-init")
}

// globals
var (
	log kitlog.Logger

	lock    sync.Mutex
	sbot    *mksbot.Sbot
	repoDir string

	viewDB *sql.DB

	longCtx  context.Context
	shutdown context.CancelFunc
)

var ErrNotInitialized = stderr.New("gosbot: not initialized or crashed")

//export ssbVersion
func ssbVersion() *C.char {
	return versionString
}

// Stop halts the running sbot and sets it's address to nil
// call BotInit again to boot a new one
// if this fails you might need to crash the app and do a full restart

//export ssbBotStop
func ssbBotStop() bool {
	lock.Lock()
	defer lock.Unlock()
	stopEvt := kitlog.With(log, "event", "botStop")
	if sbot == nil {
		level.Warn(stopEvt).Log("msg", "sbot already stopped")
		return true
	}

	shutdown()
	sbot.Shutdown()
	if sbot.Network != nil {
		ct := sbot.Network.GetConnTracker()
		sbot.Network.Close()

		// we have to set the network peer nil so that it isn't closed again by sbot.Close
		sbot.Network = nil

		level.Debug(stopEvt).Log("msg", "shutdown")
		var waited uint
		for ct.Count() > 0 && waited < 10 {
			ct.CloseAll()
			waited++
			time.Sleep(1 * time.Second)
			count := ct.Count()
			if count > 0 {
				level.Warn(stopEvt).Log("msg", "still open connectionss", "n", count)
			}
		}
	}

	if err := sbot.Close(); err != nil {
		level.Error(stopEvt).Log("err", err)
		return false
	}
	sbot = nil

	viewDB.Close()

	return true
}

//export ssbBotIsRunning
func ssbBotIsRunning() bool {
	lock.Lock()
	defer lock.Unlock()
	return sbot != nil
}

type botConfig struct {
	AppKey     string
	HMACKey    string
	KeyBlob    string
	Repo       string
	ListenAddr string
	Hops       uint
	Testing    bool

	ViewDBSchemaVersion uint `json:"SchemaVersion"` // ViewDatabase number for filename
}

var blobsNotifyHandle unsafe.Pointer

//export ssbBotInit
func ssbBotInit(config string, notifyFn uintptr) bool {
	lock.Lock()
	defer lock.Unlock()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("event", "bot init failed", "err", err)
		}
	}()

	blobsNotifyHandle = unsafe.Pointer(notifyFn)

	var cfg botConfig
	err = json.NewDecoder(strings.NewReader(config)).Decode(&cfg)
	if err != nil {
		err = errors.Wrapf(err, "BotInit: failed to decode config")
		return false
	}

	appKey := cfg.AppKey
	keyblob := cfg.KeyBlob
	repoDir = cfg.Repo
	listenAddr := cfg.ListenAddr
	hmacSignKey := cfg.HMACKey

	// create logger that writes to stderr and a timestamped file
	debugLogs := filepath.Join(repoDir, "debug")
	os.MkdirAll(debugLogs, 0700)
	logFileName := fmt.Sprintf("gobot-%s.log", time.Now().Format("2006-01-02_15-04"))
	logFile, err := os.Create(filepath.Join(debugLogs, logFileName))
	if err != nil {
		err = errors.Wrapf(err, "BotInit: failed to create debug log file")
		return false
	}
	log = kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(io.MultiWriter(os.Stderr, logFile)))
	log = kitlog.With(log, "ts", kitlog.DefaultTimestampUTC)

	if cfg.Hops == 0 || cfg.Hops > 3 {
		level.Warn(log).Log("event", "bot init", "msg", "invalid hops setting, defaulting to 1", "got", cfg.Hops)
		cfg.Hops = 1
	}

	if sbot != nil {
		err = errors.Errorf("BotInit: already initialized")
		return false
	}

	appKeyBytes, err := base64.StdEncoding.DecodeString(appKey)
	if err != nil || len(appKeyBytes) != 32 {
		err = errors.Wrapf(err, "BotInit: failed to decode passed AppKey: %s", appKey)
		return false
	}

	longCtx = context.Background()
	longCtx, shutdown = context.WithCancel(longCtx) // TODO: with Err shutting down

	_, err = os.Stat(repoDir)
	if err != nil && os.IsNotExist(err) {
		err = os.MkdirAll(repoDir, 0700)
		if err != nil {
			err = errors.Wrap(err, "BotInit: failed to create repo location")
			shutdown()
			return false
		}
	}
	r := repo.New(repoDir)

	// open viewdatabase for address-stuff
	vdbPath := filepath.Join(repoDir, "..", fmt.Sprintf("schema-built%d.sqlite?cache=shared&mode=rwc&_journal_mode=WAL", cfg.ViewDBSchemaVersion))
	viewDB, err = sql.Open("sqlite3", vdbPath)
	if err != nil {
		err = errors.Wrap(err, "BotInit: failed to open view database")
		return false
	}

	// key should be stored in keychain anyway
	os.Remove(r.GetPath("secret"))

	var kps []*ssb.KeyPair
	if cfg.Testing { // these should only be present and loaded in test environments
		keysMap, err := repo.AllKeyPairs(r)
		if err != nil {
			err = errors.Wrap(err, "sbot: failed to open all keypairs in repo")
			return false
		}
		for _, key := range keysMap {
			kps = append(kps, key)
		}
	}

	userKP, err := ssb.ParseKeyPair(strings.NewReader(keyblob))
	if err != nil {
		err = errors.Wrap(err, "sbot: failed to parse passed keypair")
		return false
	}

	doUpgradeOffsetEncoding, err := migrations.UpgradeToMultiMessage(log, r)
	if err != nil {
		err = errors.Wrap(err, "BotInit: repo migration failed")
		shutdown()
		return false
	}
	doUpgradeToRoaring, err := migrations.StillUsingBadger(log, r)
	if err != nil {
		err = errors.Wrap(err, "BotInit: badger index migration failed")
		shutdown()
		return false
	}
	if doUpgradeOffsetEncoding || doUpgradeToRoaring {
		os.RemoveAll(r.GetPath(repo.PrefixIndex))
		os.RemoveAll(r.GetPath(repo.PrefixMultiLog))
		level.Debug(log).Log("event", "db upgrade", "msg", "dropped old indexes")

		start := time.Now()
		sbot, err = mksbot.New(
			mksbot.WithInfo(log),
			mksbot.WithContext(longCtx),
			mksbot.WithRepoPath(repoDir),
			mksbot.WithJSONKeyPair(keyblob),
			mksbot.DisableNetworkNode(),
			mksbot.DisableLiveIndexMode())
		if err != nil {
			err = errors.Wrap(err, "BotInit: failed to make reindexing sbot")
			shutdown()
			return false
		}
		level.Debug(log).Log("event", "db upgrade", "msg", "sbot started", "took", time.Since(start))
		start = time.Now()
		err = sbot.Close()
		if err != nil {
			err = errors.Wrap(err, "BotInit: failed to shut down reindexed sbot")
			shutdown()
			return false
		}
		level.Info(log).Log("event", "db upgrade", "msg", "sbot done", "took", time.Since(start))
	}

	if !cfg.Testing {
		log = level.NewFilter(log, level.AllowInfo())
	}

	kps = append(kps, userKP)
	mlogPriv := multilogs.NewPrivateRead(kitlog.With(log, "module", "privLogs"), kps...)

	opts := []mksbot.Option{
		mksbot.WithInfo(log),
		mksbot.WithContext(longCtx),
		mksbot.WithRepoPath(repoDir),
		mksbot.WithAppKey(appKeyBytes),
		mksbot.WithJSONKeyPair(keyblob),
		mksbot.WithListenAddr(listenAddr),
		mksbot.WithHops(cfg.Hops),
		mksbot.EnableAdvertismentDialing(true),
		mksbot.EnableAdvertismentBroadcasts(true),
		mksbot.WithPreSecureConnWrapper(disableSigPipeWrapper),
		mksbot.WithPreSecureConnWrapper(func(c net.Conn) (net.Conn, error) {
			// TODO: make version that prints bytes "unhumanized" so that we can count them
			return countconn.WrapConn(level.Debug(log), c), nil
		}),
		// loading this plugin makes the bot badger-less but the alternative graph-builder is still experimental
		//mksbot.LateOption(mksbot.MountPlugin(&bytype.Plugin{}, plugins2.AuthMaster)),
		mksbot.LateOption(mksbot.MountMultiLog("privLogs", mlogPriv.OpenRoaring)),
	}

	if hmacSignKey != "" {
		k, err := base64.StdEncoding.DecodeString(hmacSignKey)
		if err != nil {
			err = errors.Wrap(err, "BotInit: invalid signing key")
			shutdown()
			return false
		}
		opts = append(opts, mksbot.WithHMACSigning(k))
	}

	sbot, err = mksbot.New(opts...)
	if err != nil {
		err = errors.Wrap(err, "BotInit: failed to make sbot instance")
		shutdown()
		return false
	}

	sbot.BlobStore.Changes().Register(luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			if luigi.IsEOS(err) {
				return nil
			}
			return err
		}

		n, ok := v.(ssb.BlobStoreNotification)
		if !ok {
			return errors.Errorf("blob change: unhandled notification type: %T", v)
		}

		if n.Op != ssb.BlobStoreOpPut {
			return nil
		}

		sz, err := sbot.BlobStore.Size(n.Ref)
		if err != nil {
			return err
		}

		testRef := C.CString(n.Ref.Ref())
		ret := C.callBlobsNotify(blobsNotifyHandle, C.longlong(sz), testRef)
		C.free(unsafe.Pointer(testRef))
		log.Log("event", "swift side notifyed of stored blob", "ret", ret, "blob", n.Ref.Ref())
		return nil
	}))

	log.Log("event", "serving", "self", sbot.KeyPair.Id.Ref()[1:5], "addr", listenAddr)
	go func() {
		srvErr := sbot.Network.Serve(longCtx)
		// stopErr := Stop()
		log.Log("event", "sbot node.Serve returned", "srvErr", srvErr)
		shutdown()
	}()
	return true
}

// needed for buildmode c-archive
func main() {}
