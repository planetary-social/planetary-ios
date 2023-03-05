package logging

import (
	"github.com/planetary-social/scuttlego/logging"
	"github.com/sirupsen/logrus"
)

const (
	ErrorField = "error"
)

type Logger interface {
	WithField(key string, v any) Logger

	EnabledLevel() logging.Level
	Error() logging.LoggingSystemEntry
	Debug() logging.LoggingSystemEntry
	Trace() logging.LoggingSystemEntry
}

type LogrusLogger struct {
	fields map[string]any
	system logging.LogrusLoggingSystem
}

func NewLogrusLogger(logger *logrus.Logger) *LogrusLogger {
	system := logging.NewLogrusLoggingSystem(logger)
	return &LogrusLogger{
		system: system,
		fields: make(map[string]any),
	}
}

func copyLogrusLogger(logger *LogrusLogger) *LogrusLogger {
	newLogger := &LogrusLogger{
		system: logger.system,
		fields: make(map[string]any),
	}
	for k, v := range logger.fields {
		newLogger.fields[k] = v
	}
	return newLogger
}

func (l *LogrusLogger) WithField(key string, value any) Logger {
	newLogger := copyLogrusLogger(l)
	newLogger.fields[key] = value
	return newLogger
}

func (l LogrusLogger) EnabledLevel() logging.Level {
	return l.system.EnabledLevel()
}

func (l LogrusLogger) Error() logging.LoggingSystemEntry {
	return l.addFields(l.system.Error())
}

func (l LogrusLogger) Debug() logging.LoggingSystemEntry {
	return l.addFields(l.system.Debug())
}

func (l LogrusLogger) Trace() logging.LoggingSystemEntry {
	return l.addFields(l.system.Trace())
}

func (l LogrusLogger) addFields(entry logging.LoggingSystemEntry) logging.LoggingSystemEntry {
	for k, v := range l.fields {
		entry = entry.WithField(k, v)
	}
	return entry
}
