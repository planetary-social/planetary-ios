package blobstore

import (
	"context"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/metrics"
)

type WantManagerOption func(*wantManager) error

func WantWithContext(ctx context.Context) WantManagerOption {
	return func(mgr *wantManager) error {
		mgr.longCtx = ctx
		return nil
	}
}

const DefaultMaxSize = 5 * 1024 * 1024

func WantWithMaxSize(sz uint) WantManagerOption {
	return func(mgr *wantManager) error {
		mgr.maxSize = sz
		return nil
	}
}

func WantWithLogger(l log.Logger) WantManagerOption {
	return func(mgr *wantManager) error {
		mgr.info = l
		return nil
	}
}

func WantWithMetrics(g metrics.Gauge, ctr metrics.Counter) WantManagerOption {
	return func(mgr *wantManager) error {
		mgr.gauge = g
		mgr.evtCtr = ctr
		return nil
	}
}
