package logging

import "github.com/sirupsen/logrus"

type Logger interface {
	WithError(err error) Logger
	WithField(key string, v any) Logger

	Error(message string)
	Debug(message string)
	Trace(message string)
}

type LogrusLogger struct {
	logger logrus.Ext1FieldLogger
}

func NewLogrusLogger(logger logrus.Ext1FieldLogger) LogrusLogger {
	return LogrusLogger{
		logger: logger,
	}
}

func (l LogrusLogger) WithError(err error) Logger {
	return NewLogrusLogger(l.logger.WithError(err))
}

func (l LogrusLogger) WithField(key string, v any) Logger {
	return NewLogrusLogger(l.logger.WithField(key, v))
}

func (l LogrusLogger) Error(message string) {
	l.logger.Error(message)
}

func (l LogrusLogger) Debug(message string) {
	l.logger.Debug(message)
}

func (l LogrusLogger) Trace(message string) {
	l.logger.Trace(message)
}
