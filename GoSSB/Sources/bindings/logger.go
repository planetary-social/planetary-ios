package bindings

import (
	bindingslogging "verseproj/scuttlegobridge/logging"

	"github.com/planetary-social/scuttlego/logging"
)

type LoggerAdapter struct {
	logger bindingslogging.Logger
}

func NewLoggerAdapter(logger bindingslogging.Logger) LoggerAdapter {
	return LoggerAdapter{
		logger: logger,
	}
}

func (l LoggerAdapter) New(name string) logging.Logger {
	return NewLoggerAdapter(l.logger.New(name))
}

func (l LoggerAdapter) WithError(err error) logging.Logger {
	return NewLoggerAdapter(l.logger.WithError(err))
}

func (l LoggerAdapter) WithField(key string, v interface{}) logging.Logger {
	return NewLoggerAdapter(l.logger.WithField(key, v))
}

func (l LoggerAdapter) Error(message string) {
	l.logger.Error(message)
}

func (l LoggerAdapter) Debug(message string) {
	l.logger.Debug(message)
}

func (l LoggerAdapter) Trace(message string) {
	l.logger.Trace(message)
}
