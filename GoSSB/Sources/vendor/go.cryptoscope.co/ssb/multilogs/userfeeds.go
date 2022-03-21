// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package multilogs

import (
	"context"
	"fmt"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	refs "go.mindeco.de/ssb-refs"
)

const IndexNameFeeds = "userFeeds"

func UserFeedsUpdate(ctx context.Context, seq int64, value interface{}, mlog multilog.MultiLog) error {
	if nulled, ok := value.(error); ok {
		if margaret.IsErrNulled(nulled) {
			return nil
		}
		return nulled
	}

	abstractMsg, ok := value.(refs.Message)
	if !ok {
		return fmt.Errorf("error casting message. got type %T", value)
	}

	author := abstractMsg.Author()

	authorLog, err := mlog.Get(storedrefs.Feed(author))
	if err != nil {
		return fmt.Errorf("error opening sublog: %w", err)
	}

	_, err = authorLog.Append(seq)
	if err != nil {
		return fmt.Errorf("error appending new author message: %w", err)
	}
	return nil
}
