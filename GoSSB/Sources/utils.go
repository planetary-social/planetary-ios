package main

import (
	"bytes"
	"io"
	"io/fs"
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
	"github.com/sirupsen/logrus"
	"github.com/ssbc/go-ssb"
	refs "github.com/ssbc/go-ssb-refs"
)

import "C"

//export ssbGenKey
func ssbGenKey() *C.char {
	defer logPanic()

	var err error
	defer logError("ssbGenKey", &err)

	kp, err := ssb.NewKeyPair(nil, refs.RefAlgoFeedSSB1)
	if err != nil {
		err = errors.Wrap(err, "GenerateKeyPair: keygen failed")
		return nil
	}

	buf := &bytes.Buffer{}

	err = ssb.EncodeKeyPairAsJSON(kp, buf)
	if err != nil {
		err = errors.Wrap(err, "GenerateKeyPair: failed to encode key pair as JSON")
		return nil
	}

	return C.CString(buf.String())
}

func logError(functionName string, errPtr *error) {
	if err := *errPtr; err != nil {
		log.
			Error().
			WithField(logging.ErrorField, err).
			WithField("function", functionName).
			Message("function returned an error")
	}
}

func logPanic() {
	if p := recover(); p != nil {
		log.
			Error().
			WithField("panic", p).
			WithField("stack", string(debug.Stack())).
			Message("encountered a panic")
		panic(p)
	}
}

func initPreInitLogger() {
	log = newLogger(os.Stderr, false)
	log = log.WithField("warning", "pre-init")
}

func initLogger(config bindings.BotConfig) error {
	debugLogs := logDirectory(config)
	if err := os.MkdirAll(debugLogs, 0700); err != nil {
		return errors.Wrap(err, "could not create logs directory")
	}

	logFileName := marshalLogFilename(time.Now())
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

	stdlog.SetOutput(logrusLogger.Writer())

	return logging.NewLogrusLogger(logrusLogger).WithField("source", "golang")
}

func removeOldLogFiles(cfg bindings.BotConfig) error {
	return filepath.Walk(logDirectory(cfg), func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return errors.Wrap(err, "received an error")
		}

		if !info.IsDir() && strings.HasSuffix(info.Name(), logFilenameSuffix) {
			t, err := unmarshalLogFilename(info.Name())
			if err != nil || time.Since(t) > keepLogsFor {
				if err := os.RemoveAll(path); err != nil {
					return errors.Wrap(err, "error removing a log file")
				}
			}
		}

		return nil
	})
}

func logDirectory(cfg bindings.BotConfig) string {
	return filepath.Join(cfg.Repo, "debug")
}

func marshalLogFilename(t time.Time) string {
	return logFilenamePrefix + t.Format(logFilenameFormat) + logFilenameSuffix
}

func unmarshalLogFilename(filename string) (time.Time, error) {
	filename = strings.TrimPrefix(filename, logFilenamePrefix)
	filename = strings.TrimSuffix(filename, logFilenameSuffix)
	return time.Parse(logFilenameFormat, filename)
}

// unsafeExternPointer converts a uintptr address known to be a valid pointer
// external to the Go heap to an unsafe.Pointer, without triggering the
// unsafeptr vet warning.
func unsafeExternPointer(addr uintptr) unsafe.Pointer {
	// Converting a uintptr directly to an unsafe.Pointer triggers a vet warning,
	// because a uintptr cannot safely hold a pointer to the Go heap. (Because a
	// uintptr may hold an integer, uintptr values are not traced during garbage
	// collection and are not updated during stack resizing.)
	//
	// However, if we know that the address is not owned by the Go heap, it does
	// not need to be traced by the GC and cannot be implicitly relocated.
	// We silence the unsafeptr warning by converting a pointer-to-uintptr to
	// a pointer-to-pointer.
	return *(*unsafe.Pointer)(unsafe.Pointer(&addr))
}
