// SPDX-License-Identifier: MIT

package gossip

import (
	"bytes"
	"context"
	"encoding/json"
	"time"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/muxrpc/codec"
	"golang.org/x/sync/errgroup"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/message"
)

func (h *handler) fetchAll(
	ctx context.Context,
	e muxrpc.Endpoint,
	fs *graph.StrFeedSet,
) error {
	// we don't just want them all parallel right nw
	// this kind of concurrency is way to harsh on the runtime
	// we need some kind of FeedManager, similar to Blobs
	// which we can ask for which feeds aren't in transit,
	// due for a (probabilistic) update
	// and manage live feeds more granularly across open connections

	lst, err := fs.List()
	if err != nil {
		return err
	}
	tGraph, err := h.graphBuilder.Build()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithCancel(ctx)
	fetchGroup, ctx := errgroup.WithContext(ctx)
	work := make(chan *ssb.FeedRef)

	n := len(lst)
	// n := 1 + (len(lst) / 10)
	const maxWorker = 50
	if n > maxWorker { // n = max(n,maxWorker)
		n = maxWorker
	}
	for i := n; i > 0; i-- {
		fetchGroup.Go(h.makeWorker(work, ctx, e))
	}

	for _, r := range lst {
		if tGraph.Blocks(h.self, r) {
			continue
		}
		select {
		case <-ctx.Done():
			close(work)
			cancel()
			fetchGroup.Wait()
			return ctx.Err()
		case work <- r:
		}
	}
	close(work)
	// level.Debug(h.Info).Log("event", "feed fetch workers filled", "n", n)
	err = fetchGroup.Wait()
	// level.Debug(h.Info).Log("event", "workers done", "err", err)
	return err
}

func (h *handler) makeWorker(work <-chan *ssb.FeedRef, ctx context.Context, edp muxrpc.Endpoint) func() error {
	started := time.Now()
	return func() error {
		for ref := range work {
			err := h.fetchFeed(ctx, ref, edp, started)
			if muxrpc.IsSinkClosed(err) || errors.Cause(err) == context.Canceled || errors.Cause(err) == muxrpc.ErrSessionTerminated {
				return err
			} else if err != nil {
				// just logging the error assuming forked feed for instance
				level.Warn(h.logger).Log("event", "skipped updating of stored feed", "err", err, "fr", ref.Ref()[1:5])
			}
		}
		return nil
	}
}

func isIn(list []librarian.Addr, a *ssb.FeedRef) bool {
	for _, el := range list {
		if bytes.Equal([]byte(a.StoredAddr()), []byte(el)) {
			return true
		}
	}
	return false
}

// fetchFeed requests the feed fr from endpoint e into the repo of the handler
func (g *handler) fetchFeed(
	ctx context.Context,
	fr *ssb.FeedRef,
	edp muxrpc.Endpoint,
	started time.Time,
) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}
	// check our latest
	addr := fr.StoredAddr()
	g.activeLock.Lock()
	_, ok := g.activeFetch.Load(addr)
	if ok {
		level.Warn(g.logger).Log("fetchFeed", "crawl active", "addr", fr.Ref()[1:5])
		g.activeLock.Unlock()
		return nil
	}
	if g.sysGauge != nil {
		g.sysGauge.With("part", "fetches").Add(1)
	}
	g.activeFetch.Store(addr, true)
	g.activeLock.Unlock()
	defer func() {
		g.activeLock.Lock()
		g.activeFetch.Delete(addr)
		g.activeLock.Unlock()
		if g.sysGauge != nil {
			g.sysGauge.With("part", "fetches").Add(-1)
		}
	}()
	userLog, err := g.feedIndex.Get(addr)
	if err != nil {
		return errors.Wrapf(err, "failed to open sublog for user")
	}
	latest, err := userLog.Seq().Value()
	if err != nil {
		return errors.Wrapf(err, "failed to observe latest")
	}
	var (
		latestSeq margaret.BaseSeq
		latestMsg ssb.Message
	)
	switch v := latest.(type) {
	case librarian.UnsetValue:
		// nothing stored, fetch from zero
	case margaret.BaseSeq:
		latestSeq = v + 1 // sublog is 0-init while ssb chains start at 1
		if v >= 0 {
			rootLogValue, err := userLog.Get(v)
			if err != nil {
				return errors.Wrapf(err, "failed to look up root seq for latest user sublog")
			}
			msgV, err := g.receiveLog.Get(rootLogValue.(margaret.Seq))
			if err != nil {
				return errors.Wrapf(err, "failed retreive stored message")
			}

			var ok bool
			latestMsg, ok = msgV.(ssb.Message)
			if !ok {
				return errors.Errorf("fetch: wrong message type. expected %T - got %T", latestMsg, msgV)
			}

			// make sure our house is in order
			if hasSeq := latestMsg.Seq(); hasSeq != latestSeq.Seq() {
				return ssb.ErrWrongSequence{Ref: fr, Stored: latestMsg, Logical: latestSeq}
			}
		}
	}

	startSeq := latestSeq
	info := log.With(g.logger, "event", "gossiprx",
		"fr", fr.Ref()[1:5],
		"latest", startSeq) // , "me", g.Id.Ref()[1:5])

	var q = message.CreateHistArgs{
		ID:         fr,
		Seq:        int64(latestSeq + 1),
		StreamArgs: message.StreamArgs{Limit: -1},
	}

	toLong, cancel := context.WithTimeout(ctx, 10*time.Minute)
	defer func() {
		cancel()
		if n := latestSeq - startSeq; n > 0 {
			if g.sysGauge != nil {
				g.sysGauge.With("part", "msgs").Add(float64(n))
			}
			if g.sysCtr != nil {
				g.sysCtr.With("event", "gossiprx").Add(float64(n))
			}
			level.Debug(info).Log("received", n, "took", time.Since(started))
		}
	}()

	method := muxrpc.Method{"createHistoryStream"}

	store := luigi.FuncSink(func(ctx context.Context, val interface{}, err error) error {
		if err != nil {
			if luigi.IsEOS(err) {
				return nil
			}
			return err
		}
		seq, err := g.receiveLog.Append(val)
		msg := val.(ssb.Message)
		level.Warn(info).Log("receivedAsSeq", seq.Seq(), "ref", msg.Key().Ref())
		return errors.Wrap(err, "failed to append verified message to rootLog")
	})

	var (
		src luigi.Source
		snk luigi.Sink = message.NewVerifySink(fr, latestSeq, latestMsg, store, g.hmacSec)
	)

	switch fr.Algo {
	case ssb.RefAlgoFeedSSB1:
		src, err = edp.Source(toLong, json.RawMessage{}, method, q)
	case ssb.RefAlgoFeedGabby:
		src, err = edp.Source(toLong, codec.Body{}, method, q)
	}
	if err != nil {
		return errors.Wrapf(err, "fetchFeed(%s:%d) failed to create source", fr.Ref(), latestSeq)
	}

	// count the received messages
	snk = mfr.SinkMap(snk, func(_ context.Context, val interface{}) (interface{}, error) {
		latestSeq++
		return val, nil
	})

	// level.Warn(info).Log("starting", "fetch")
	err = luigi.Pump(toLong, snk, src)
	// level.Warn(info).Log("done", "fetch", "lastSeq", latestSeq)
	return errors.Wrap(err, "gossip pump failed")
}
