package bindings

import (
	kitlog "github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/planetary-social/scuttlego/logging"
)

type KitlogLogger struct {
	name   string
	level  logging.Level
	logger kitlog.Logger
}

func NewKitlogLogger(logger kitlog.Logger, name string, level logging.Level) KitlogLogger {
	return KitlogLogger{
		name:   name,
		level:  level,
		logger: logger,
	}
}

func (l KitlogLogger) New(name string) logging.Logger {
	return NewKitlogLogger(l.logger, l.name+"."+name, l.level)
}

func (l KitlogLogger) WithError(err error) logging.Logger {
	return NewKitlogLogger(kitlog.With(l.logger, "err", err), l.name, l.level)
}

func (l KitlogLogger) WithField(key string, v interface{}) logging.Logger {
	return NewKitlogLogger(kitlog.With(l.logger, key, v), l.name, l.level)
}

func (l KitlogLogger) Error(message string) {
	if l.level >= logging.LevelError {
		level.Error(l.withName()).Log("message", message)
	}
}

func (l KitlogLogger) Debug(message string) {
	if l.level >= logging.LevelDebug {
		level.Debug(l.withName()).Log("message", message)
	}
}

func (l KitlogLogger) Trace(message string) {
	if l.level >= logging.LevelTrace {
		level.Debug(l.withName()).Log("message", message)
	}
}

func (l KitlogLogger) withName() kitlog.Logger {
	return kitlog.With(l.logger, "name", l.name)
}
