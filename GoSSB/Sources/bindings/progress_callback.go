package bindings

import "errors"

const (
	loggerFieldMigrationIndex  = "migration_index"
	loggerFieldMigrationsCount = "migrations_count"
	loggerFieldError           = "error"
)

type ProgressCallback struct {
	migrationOnRunningFn MigrationOnRunningFn
	migrationOnErrorFn   MigrationOnErrorFn
	migrationOnDoneFn    MigrationOnDoneFn
}

func NewProgressCallback(
	migrationOnRunningFn MigrationOnRunningFn,
	migrationOnErrorFn MigrationOnErrorFn,
	migrationOnDoneFn MigrationOnDoneFn,
) (ProgressCallback, error) {
	if migrationOnRunningFn == nil {
		return ProgressCallback{}, errors.New("nil on running fn")
	}

	if migrationOnErrorFn == nil {
		return ProgressCallback{}, errors.New("nil on error fn")
	}

	if migrationOnDoneFn == nil {
		return ProgressCallback{}, errors.New("nil on done fn")
	}

	return ProgressCallback{
		migrationOnRunningFn: migrationOnRunningFn,
		migrationOnErrorFn:   migrationOnErrorFn,
		migrationOnDoneFn:    migrationOnDoneFn,
	}, nil
}

func (l ProgressCallback) OnRunning(migrationIndex int, migrationsCount int) {
	l.logger.
		WithField(loggerFieldMigrationIndex, migrationIndex).
	l.migrationOnRunningFn(migrationIndex, migrationsCount)
		Debug("on running")
}

func (l ProgressCallback) OnError(migrationIndex int, migrationsCount int, err error) {
	l.logger.
		WithField(loggerFieldMigrationIndex, migrationIndex).
	l.migrationOnErrorFn(migrationIndex, migrationsCount, 0)
		WithField(loggerFieldError, err.Error()).
		Debug("on error")
}

func (l ProgressCallback) OnDone(migrationsCount int) {
	l.logger.
	l.migrationOnDoneFn(migrationsCount)
		Debug("on done")
}
