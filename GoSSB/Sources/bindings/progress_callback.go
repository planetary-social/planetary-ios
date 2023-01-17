package bindings

import "github.com/planetary-social/scuttlego/logging"

const (
	loggerFieldMigrationIndex  = "migration_index"
	loggerFieldMigrationsCount = "migrations_count"
	loggerFieldError           = "error"
)

type LogProgressCallback struct {
	logger logging.Logger
}

func NewLogProgressCallback(logger logging.Logger) *LogProgressCallback {
	return &LogProgressCallback{
		logger: logger.New("progress_callback"),
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
