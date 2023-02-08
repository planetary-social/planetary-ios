package bindings

import (
	bindingslogging "verseproj/scuttlegobridge/logging"
)

const (
	loggerFieldMigrationIndex  = "migration_index"
	loggerFieldMigrationsCount = "migrations_count"
	loggerFieldError           = "error"
)

type LogProgressCallback struct {
	logger bindingslogging.Logger
}

func NewLogProgressCallback(logger bindingslogging.Logger) *LogProgressCallback {
	return &LogProgressCallback{
		logger: logger,
	}
}

func (l LogProgressCallback) OnRunning(migrationIndex int, migrationsCount int) {
	l.logger.
		WithField(loggerFieldMigrationIndex, migrationIndex).
		WithField(loggerFieldMigrationsCount, migrationsCount).
		Debug("on running")
}

func (l LogProgressCallback) OnError(migrationIndex int, migrationsCount int, err error) {
	l.logger.
		WithField(loggerFieldMigrationIndex, migrationIndex).
		WithField(loggerFieldMigrationsCount, migrationsCount).
		WithField(loggerFieldError, err.Error()).
		Debug("on error")
}

func (l LogProgressCallback) OnDone(migrationsCount int) {
	l.logger.
		WithField(loggerFieldMigrationsCount, migrationsCount).
		Debug("on done")
}
