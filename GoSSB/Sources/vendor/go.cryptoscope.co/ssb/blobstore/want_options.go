// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobstore

import (
	"context"

	"github.com/go-kit/kit/metrics"
	"go.mindeco.de/log"
)

// WantManagerOption is used to tune different aspects of the WantManager.
type WantManagerOption func(*WantManager) error

// WantWithContext supplies a context to cancel its operations.
func WantWithContext(ctx context.Context) WantManagerOption {
	return func(mgr *WantManager) error {
		mgr.longCtx = ctx
		return nil
	}
}

// DefaultMaxSize is 5 megabyte. Blobs that are biggere are not fetched.
const DefaultMaxSize = 5 * 1024 * 1024

// WantWithMaxSize can be used to change DefaultMaxSize
func WantWithMaxSize(sz uint) WantManagerOption {
	return func(mgr *WantManager) error {
		mgr.maxSize = sz
		return nil
	}
}

// WantWithLogger sets up the logger which is used for debug and info output.
func WantWithLogger(l log.Logger) WantManagerOption {
	return func(mgr *WantManager) error {
		mgr.info = l
		return nil
	}
}

// WantWithMetrics setup the metrics counters and gauges to monitor the want manager.
func WantWithMetrics(g metrics.Gauge, ctr metrics.Counter) WantManagerOption {
	return func(mgr *WantManager) error {
		mgr.gauge = g
		mgr.evtCtr = ctr
		return nil
	}
}
