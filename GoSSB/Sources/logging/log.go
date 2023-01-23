package logging

import "github.com/sirupsen/logrus"

type Logger interface {
	New(name string) Logger
	WithError(err error) Logger
	WithField(key string, v any) Logger

	Error(message string)
	Debug(message string)
	Trace(message string)
}

type LogrusLogger struct {
	name   string
	logger logrus.Ext1FieldLogger
}

func NewLogrusLogger(logger logrus.Ext1FieldLogger, name string) LogrusLogger {
	return LogrusLogger{
		name:   name,
		logger: logger,
	}
}

func (l LogrusLogger) New(name string) Logger {
	return NewLogrusLogger(l.logger, l.name+"."+name)
}

func (l LogrusLogger) WithError(err error) Logger {
	return NewLogrusLogger(l.logger.WithError(err), l.name)
}

func (l LogrusLogger) WithField(key string, v any) Logger {
	return NewLogrusLogger(l.logger.WithField(key, v), l.name)
}

func (l LogrusLogger) Error(message string) {
	l.withName().Error(message)
}

func (l LogrusLogger) Debug(message string) {
	l.withName().Debug(message)
}

func (l LogrusLogger) Trace(message string) {
	l.withName().Trace(message)
}

func (l LogrusLogger) withName() logrus.Ext1FieldLogger {
	return l.logger.WithField("name", l.name)
}
