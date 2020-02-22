package migrations

import (
	"os"

	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/repo"
)

func StillUsingBadger(log logging.Interface, r repo.Interface) (bool, error) {
	v := CurrentVersion(r)
	switch {
	case v == 1:
		// do the deed
	case v < 1:
		level.Error(log).Log("event", "repo is not version 1 yet", "v", v)
		return false, nil
	default:
		return false, errors.Errorf("sbot/repo migrate: invalid version: %d", v)
	}

	// check the db and the state file
	var hasDB, hasState bool

	dbPath := r.GetPath(repo.PrefixMultiLog, multilogs.IndexNameFeeds, "db")
	_, err := os.Stat(dbPath)
	if err != nil && !os.IsNotExist(err) {
		return false, errors.Wrap(err, "StillUsingBadger: failed to check old db path inside the repo")
	}
	if err == nil {
		hasDB = true
	}

	stateFilePath := r.GetPath(repo.PrefixMultiLog, multilogs.IndexNameFeeds, "state.json")
	_, err = os.Stat(stateFilePath)
	if err != nil && !os.IsNotExist(err) {
		return false, errors.Wrap(err, "StillUsingBadger: failed to check old state file path inside the repo")
	}
	if err == nil {
		hasState = true
	}

	return hasDB && hasState, nil
}
