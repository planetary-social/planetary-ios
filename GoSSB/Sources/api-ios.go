// Copyright (C) 2019 Henry Bubert <cryptix@riseup.net>. All Rights Reserved.

// scuttlebridge, makefile style
package main

// #include <stdlib.h>
// #include <sys/types.h>
// #include <stdint.h>
// #include <stdbool.h>
//
// static bool callNotifyBlobs(void *func, int64_t size, const char *blobRef)
// {
//     return ((bool(*)(int64_t, const char *))func)(size, blobRef);
// }
//
// static void callNotifyMigrationOnRunning(void *func, int64_t migrationIndex, int64_t migrationsCount)
// {
//     ((void(*)(int64_t, int64_t))func)(migrationIndex, migrationsCount);
// }
//
// static void callNotifyMigrationOnError(void *func, int64_t migrationIndex, int64_t migrationsCount, int64_t error)
// {
//     ((void(*)(int64_t, int64_t, int64_t))func)(migrationIndex, migrationsCount, error);
// }
//
// static void callNotifyMigrationOnDone(void *func, int64_t migrationsCount)
// {
//     ((void(*)(int64_t))func)(migrationsCount);
// }
import "C"

import (
	"encoding/json"
	"fmt"
	"io"
	stdlog "log"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"time"
	"unsafe"
	"verseproj/scuttlegobridge/bindings"
	"verseproj/scuttlegobridge/logging"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/queries"
	"github.com/sirupsen/logrus"
)

const (
	kilobyte = 1000
	megabyte = 1000 * kilobyte
)
const (
	memoryLimitInBytes = 500 * megabyte
)

func init() {
	initPreInitLogger()

	debug.SetMemoryLimit(memoryLimitInBytes)
}

var (
	log  logging.Logger
	node = bindings.NewNode()
)

//export ssbBotStop
func ssbBotStop() bool {
	defer logPanic()

	var err error
	defer logError("ssbBotStop", &err)

	err = node.Stop()
	if err != nil {
		if !errors.Is(err, bindings.ErrNodeIsNotRunning) {
			err = errors.Wrap(err, "failed to stop the node")
			return false
		}
	}

	return true
}

//export ssbBotIsRunning
func ssbBotIsRunning() bool {
	defer logPanic()

	return node.IsRunning()
}

// Three callbacks are used to notify about progress when running migrations:
//   - OnRunning is called when a particular migration has to be
//     executed. If all migrations were already executed this callback will not be
//     called. If status loading fails for a migration this callback will not
//     be executed.
//   - OnError is called when a particular migration fails. If this
//     callback is triggered it is only triggered once and is the last
//     callback to be triggered. The error parameter specifies the type of encountered error:
//     0. Unknown error.
//   - OnDone is called once there are no more migrations remaining to
//     be executed. This includes the scenario when there are no more migrations to consider.
//     If this callback is triggered it is triggered only once and is the last callback to be triggered.
//
// Example valid call sequences:
//
// - no migrations:
//   - OnDone(count=0)
//
// - we had three migrations, they all had to be run and executed correctly:
//   - OnRunning(index=0, count=3)
//   - OnRunning(index=1, count=3)
//   - OnRunning(index=2, count=3)
//   - OnDone(count=3)
//
// - we had three migrations, not all had to be run and they executed correctly:
//   - OnRunning(index=2, count=3)
//   - OnDone(count=3)
//
// - we had three migrations, they all had to be run and the second one failed:
//
//   - OnRunning(index=0, count=3)
//
//   - OnRunning(index=1, count=3)
//
//   - OnError(index=1, count=3)
//
//   - we had three migrations, one migration executed correctly and status
//     loading failed for the second one:
//
//   - OnRunning(index=0, count=3)
//
//   - OnError(index=1, count=3)
//
//export ssbBotInit
func ssbBotInit(
	config string,
	notifyBlobReceivedFn uintptr,
	notifyMigrationOnRunningFn uintptr,
	notifyMigrationOnErrorFn uintptr,
	notifyMigrationOnDoneFn uintptr,
) bool {
	defer logPanic()

	var err error
	defer logError("ssbBotInit", &err)

	var cfg bindings.BotConfig
	err = json.NewDecoder(strings.NewReader(config)).Decode(&cfg)
	if err != nil {
		err = errors.Wrap(err, "failed to decode config")
		return false
	}

	err = initLogger(cfg)
	if err != nil {
		err = errors.Wrap(err, "failed to init logger")
		return false
	}

	onBlobDownloadedFn := func(event queries.BlobDownloaded) error {
		ref := C.CString(event.Id.String())
		ret := C.callNotifyBlobs(unsafe.Pointer(notifyBlobReceivedFn), C.int64_t(event.Size.InBytes()), ref)
		C.free(unsafe.Pointer(ref))
		if !ret {
			return errors.New("calling C function failed")
		}
		return nil
	}

	migrationOnRunningFn := func(migrationIndex, migrationsCount int) {
		if notifyMigrationOnRunningFn != 0 {
			C.callNotifyMigrationOnRunning(unsafe.Pointer(notifyMigrationOnRunningFn), C.int64_t(migrationIndex), C.int64_t(migrationsCount))
		}
	}

	migrationOnErrorFn := func(migrationIndex, migrationsCount, error int) {
		if notifyMigrationOnErrorFn != 0 {
			C.callNotifyMigrationOnError(unsafe.Pointer(notifyMigrationOnErrorFn), C.int64_t(migrationIndex), C.int64_t(migrationsCount), C.int64_t(error))
		}
	}

	migrationOnDoneFn := func(migrationsCount int) {
		if notifyMigrationOnDoneFn != 0 {
			C.callNotifyMigrationOnDone(unsafe.Pointer(notifyMigrationOnDoneFn), C.int64_t(migrationsCount))
		}
	}

	err = node.Start(cfg, log, onBlobDownloadedFn, migrationOnRunningFn, migrationOnErrorFn, migrationOnDoneFn)
	if err != nil {
		err = errors.Wrap(err, "failed to start node")
		return false
	}

	return true
}

// needed for buildmode c-archive
func main() {}

func initPreInitLogger() {
	log = newLogger(os.Stderr, false)
	log = log.WithField("warning", "pre-init")
}

func initLogger(config bindings.BotConfig) error {
	debugLogs := filepath.Join(config.Repo, "debug")
	if err := os.MkdirAll(debugLogs, 0700); err != nil {
		return errors.Wrap(err, "could not create logs directory")
	}

	logFileName := fmt.Sprintf("gobot-%s.log", time.Now().Format("2006-01-02_15-04"))
	logFile, err := os.Create(filepath.Join(debugLogs, logFileName))
	if err != nil {
		return errors.Wrap(err, "failed to create debug log file")
	}

	log = newLogger(io.MultiWriter(os.Stderr, logFile), config.Testing)
	return nil
}

func newLogger(w io.Writer, testing bool) logging.Logger {
	const swiftLikeFormat = "2006-01-02 15:04:05.0000000 (UTC)"

	customFormatter := new(logrus.TextFormatter)
	customFormatter.TimestampFormat = swiftLikeFormat

	logrusLogger := logrus.New()
	logrusLogger.SetOutput(w)
	logrusLogger.SetFormatter(customFormatter)
	if testing {
		logrusLogger.SetLevel(logrus.TraceLevel)
	} else {
		logrusLogger.SetLevel(logrus.DebugLevel)
	}

	logrusLoggerEntry := logrusLogger.WithField("source", "golang")
	stdlog.SetOutput(logrusLoggerEntry.Writer())
	return logging.NewLogrusLogger(logrusLoggerEntry)
}
