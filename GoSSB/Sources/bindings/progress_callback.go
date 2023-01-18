package bindings

import "errors"

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
	l.migrationOnRunningFn(migrationIndex, migrationsCount)
}

func (l ProgressCallback) OnError(migrationIndex int, migrationsCount int, err error) {
	l.migrationOnErrorFn(migrationIndex, migrationsCount, 0)
}

func (l ProgressCallback) OnDone(migrationsCount int) {
	l.migrationOnDoneFn(migrationsCount)
}
