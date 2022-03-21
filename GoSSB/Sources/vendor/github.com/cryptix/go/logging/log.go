package logging

import (
	"fmt"
	"io"
	stdlog "log"
	"os"

	kitlog "github.com/go-kit/kit/log"
	"github.com/pkg/errors"
)

var closeChan chan<- os.Signal

// SetCloseChan sets a signal channel that is sent to when CheckFatal is used
func SetCloseChan(c chan<- os.Signal) {
	closeChan = c
}

// CheckFatal exits the process if err != nil
func CheckFatal(err error) {
	if err != nil {
		l := internal
		if l == nil {
			l = kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stderr))
			l = kitlog.With(l, "module", "logging", "caller", kitlog.DefaultCaller)
		}
		l.Log("check", "fatal", "err", err)
		if err := LogPanicWithStack(l, "CheckFatal", err); err != nil {
			panic(errors.Wrap(err, "CheckFatal could not dump error"))
		}
		if closeChan != nil {
			l.Log("check", "notice", "msg", "Sending close message")
			closeChan <- os.Interrupt
		}
		os.Exit(1)
	}
}

var internal kitlog.Logger

// SetupLogging will initialize the logger backend and set the flags.
func SetupLogging(w io.Writer) {

	if w == nil {
		w = os.Stderr
	}

	logger := kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(w))

	if internal != nil {
		logger.Log("event", "warning", "msg", "logging inited twice")
		return
	}

	if lvl := os.Getenv("CRYPTIX_LOGLVL"); lvl != "" {
		logger.Log("module", "logging", "error", "CRYPTIX_LOGLVL is obsolete. levels are bad, mkay?")
	}
	// wrap logger to error-check the writes only once
	internal = kitlog.LoggerFunc(func(keyvals ...interface{}) error {
		if err := logger.Log(keyvals...); err != nil {
			fmt.Fprintf(w, "warning: logger.Write() failed! %s - vals: %v", err, keyvals)
			panic(err) // no other way to escalate this
		}
		return nil
	})
	internal = kitlog.With(internal, "time", kitlog.DefaultTimestamp, "caller", kitlog.DefaultCaller)
	stdlog.SetOutput(kitlog.NewStdlibAdapter(kitlog.With(internal, "module", "stdlib")))
}

// Interface renames the (go-kit/log).Logger interface for conveninence
type Interface kitlog.Logger

// Logger returns an Entry where the module field is set to name
func Logger(name string) kitlog.Logger {
	l := internal
	if l == nil {
		l = kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stderr))
		l = kitlog.With(l, "warning", "uninitizialized", kitlog.DefaultCaller)
	}
	if name == "" {
		l.Log("module", "logger", "error", "missing name parameter")
		name = "undefined"
	}
	return kitlog.With(l, "module", name)
}
