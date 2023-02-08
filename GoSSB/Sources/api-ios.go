// Copyright (C) 2019 Henry Bubert <cryptix@riseup.net>. All Rights Reserved.

// scuttlebridge, makefile style
package main

// #include <stdlib.h>
// #include <sys/types.h>
// #include <stdint.h>
// #include <stdbool.h>
// static bool callNotifyBlobs(void *func, int64_t size, const char *blobRef)
// {
//     return ((bool(*)(int64_t, const char *))func)(size, blobRef);
// }
//
// static void callNotifyNewBearerToken(void *func, const char *token, int64_t expires)
// {
//     return ((void(*)(const char *, int64_t))func)(token, expires);
// }
import "C"

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"time"
	"unsafe"
	"verseproj/scuttlegobridge/bindings"
	"verseproj/scuttlegobridge/logging"

	kitlog "github.com/go-kit/kit/log"
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

//export ssbVersion
func ssbVersion() *C.char {
	return C.CString("project-raptor") // todo remove this function, I don't see why we need this
}

//export ssbBotStop
func ssbBotStop() bool {
	var err error
	defer logError("ssbBotStop", &err)

	err = node.Stop()
	if err != nil {
		err = errors.Wrap(err, "failed to stop the node")
	}

	return true
}

//export ssbBotIsRunning
func ssbBotIsRunning() bool {
	return node.IsRunning()
}

//export ssbBotInit
func ssbBotInit(config string, notifyBlobReceivedFn uintptr, notifyNewBearerTokenFn uintptr) bool {
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

	fn := func(event queries.BlobDownloaded) error {
		ref := C.CString(event.Id.String())
		ret := C.callNotifyBlobs(unsafe.Pointer(notifyBlobReceivedFn), C.int64_t(event.Size.InBytes()), ref)
		C.free(unsafe.Pointer(ref))
		if !ret {
			return errors.New("calling C function failed")
		}
		return nil
	}

	err = node.Start(cfg, log, fn)
	if err != nil {
		err = errors.Wrap(err, "failed to start node")
		return false
	}

	return true
}

// needed for buildmode c-archive
func main() {}

func initPreInitLogger() {
	log = newLogger(os.Stderr)
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

	log = newLogger(kitlog.NewSyncWriter(io.MultiWriter(os.Stderr, logFile)))
	return nil
}

func newLogger(w io.Writer) logging.Logger {
	const swiftLikeFormat = "2006-01-02 15:04:05.0000000 (UTC)"

	customFormatter := new(logrus.TextFormatter)
	customFormatter.TimestampFormat = swiftLikeFormat

	logrusLogger := logrus.New()
	logrusLogger.SetOutput(w)
	logrusLogger.SetFormatter(customFormatter)
	logrusLogger.SetLevel(logrus.DebugLevel)

	return logging.NewLogrusLogger(logrusLogger).WithField("source", "golang")
}
