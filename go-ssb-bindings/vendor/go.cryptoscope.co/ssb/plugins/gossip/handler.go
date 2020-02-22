// SPDX-License-Identifier: MIT

package gossip

import (
	"context"
	"sync"
	"time"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/go-kit/kit/metrics"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/message"
)

type handler struct {
	self *ssb.FeedRef

	receiveLog   margaret.Log
	feedIndex    multilog.MultiLog
	graphBuilder graph.Builder

	logger log.Logger

	hmacSec  HMACSecret
	hopCount int
	promisc  bool // ask for remote feed even if it's not on owns fetch list

	activeLock  sync.Mutex
	activeFetch sync.Map

	sysGauge metrics.Gauge
	sysCtr   metrics.Counter

	pushManager *FeedPushManager
	pull        *pullManager

	rootCtx context.Context
}

func (h *handler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {
	remote := e.Remote()
	remoteRef, err := ssb.GetFeedRefFromAddr(remote)
	if err != nil {
		return
	}

	if remoteRef.Equal(h.self) {
		return
	}

	info := log.With(h.logger, "remote", remoteRef.Ref()[1:5], "event", "gossiprx")

	if h.promisc {
		hasCallee, err := multilog.Has(h.feedIndex, remoteRef.StoredAddr())
		if err != nil {
			info.Log("handleConnect", "multilog.Has(callee)", "err", err)
			return
		}

		if !hasCallee {
			info.Log("handleConnect", "oops - dont have feed of remote peer. requesting...")
			if err := h.fetchFeed(ctx, remoteRef, e, time.Now()); err != nil {
				info.Log("handleConnect", "fetchFeed callee failed", "err", err)
				return
			}
			info.Log("msg", "done fetching callee")
		}
	}

	h.pull.RequestFeeds(ctx, e)

	/*
		// TODO: ctx to build and list?!
		// or pass rootCtx to their constructor but than we can't cancel sessions
		select {
		case <-ctx.Done():
			return
		default:
		}

		hops := h.graphBuilder.Hops(h.self, h.hopCount)
		if hops != nil {
			err := h.fetchAll(ctx, e, hops)
			if muxrpc.IsSinkClosed(err) || errors.Cause(err) == context.Canceled {
				return
			}
			if err != nil {
				level.Error(info).Log("msg", "hops failed", "err", err)
			}
		}
	*/
}

func (h *handler) HandleCall(
	ctx context.Context,
	req *muxrpc.Request,
	edp muxrpc.Endpoint,
) {
	if req.Type == "" {
		req.Type = "async"
	}

	hlog := log.With(h.logger, "event", "gossiptx")
	errLog := level.Error(hlog)
	dbgLog := level.Debug(hlog)

	closeIfErr := func(err error) {
		if err != nil {
			errLog.Log("err", err)
			req.Stream.CloseWithError(err)
			return
		}
		req.Stream.Close()
	}

	switch req.Method.String() {

	case "createHistoryStream":
		//  https://ssbc.github.io/scuttlebutt-protocol-guide/#createHistoryStream
		args := req.Args()
		if req.Type != "source" {
			closeIfErr(errors.Errorf("wrong tipe. %s", req.Type))
			return
		}
		if len(args) < 1 {
			err := errors.New("ssb/message: not enough arguments, expecting feed id")
			closeIfErr(err)
			return
		}
		argMap, ok := args[0].(map[string]interface{})
		if !ok {
			err := errors.Errorf("ssb/message: not the right map - %T", args[0])
			closeIfErr(err)
			return
		}
		query, err := message.NewCreateHistArgsFromMap(argMap)
		if err != nil {
			closeIfErr(errors.Wrap(err, "bad request"))
			return
		}

		remote, err := ssb.GetFeedRefFromAddr(edp.Remote())
		if err != nil {
			closeIfErr(errors.Wrap(err, "bad remote"))
			return
		}

		// hlog = log.With(hlog, "fr", query.ID.Ref()[1:5], "remote", remote.Ref()[1:5])
		// dbgLog = level.Warn(hlog)

		// skip this check for self/master or in promisc mode (talk to everyone)
		if !(h.self.Equal(remote) || h.promisc) {
			tg, err := h.graphBuilder.Build()
			if err != nil {
				closeIfErr(errors.Wrap(err, "internal error"))
				return
			}

			if tg.Blocks(query.ID, remote) {
				dbgLog.Log("msg", "feed blocked")
				req.Stream.Close()
				return
			}

			// TODO: write proper tests for this
			// // see if there is a path from the wanted feed
			// l, err := tg.MakeDijkstra(query.ID)
			// if err != nil {
			// 	if _, ok := errors.Cause(err).(graph.ErrNoSuchFrom); ok {
			// 		dbgLog.Log("msg", "unknown remote")
			// 		req.Stream.Close()
			// 		return
			// 	}
			// 	closeIfErr(errors.Wrap(err, "graph dist lookup failed"))
			// 	return
			// }

			// // to the remote requesting it
			// path, dist := l.Dist(remote)
			// if len(path) < 1 || len(path) > 4 {
			// 	dbgLog.Log("msg", "requested feed doesnt know remote", "d", dist, "plen", len(path))
			// 	req.Stream.Close()
			// 	return
			// }
			// now we know that at least someone they know, knows the remote

			// dbgLog.Log("msg", "feeds in range", "d", dist, "plen", len(path))
			// } else {
			// dbgLog.Log("msg", "feed access granted")
		}

		err = h.pushManager.CreateStreamHistory(ctx, req.Stream, query)
		if err != nil {
			if luigi.IsEOS(err) {
				req.Stream.Close()
				return
			}
			err = errors.Wrap(err, "createHistoryStream failed")
			level.Error(hlog).Log("err", err)
			req.Stream.CloseWithError(err)
			return
		}
		// don't close stream (pushManager will pass it on to live processing or close it itself)

	case "gossip.ping":
		err := req.Stream.Pour(ctx, time.Now().UnixNano()/1000000)
		if err != nil {
			closeIfErr(errors.Wrapf(err, "pour failed to pong"))
			return
		}
		// just leave this stream open.
		// some versions of ssb-gossip don't like if the stream is closed without an error

	default:
		closeIfErr(errors.Errorf("unknown command: %q", req.Method.String()))
	}
}
