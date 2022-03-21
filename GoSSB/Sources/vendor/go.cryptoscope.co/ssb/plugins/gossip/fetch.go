// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package gossip

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"time"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	"golang.org/x/sync/errgroup"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/neterr"
	"go.cryptoscope.co/ssb/message"
	refs "go.mindeco.de/ssb-refs"
)

func (h *LegacyGossip) FetchAll(
	ctx context.Context,
	e muxrpc.Endpoint,
	set *ssb.StrFeedSet,
	withLive bool,
) error {
	lst, err := set.List()
	if err != nil {
		return err
	}

	// TODO: warning unbound parallellism ahead.
	// since we don't have a way yet to handoff a feed
	// all feeds will be stuck in the pool.
	//
	// this is very bad if you have a lot of them.
	//
	// ebt will make this better
	// we need some kind of pull feed manager, similar to Blobs
	// which we can ask for which feeds aren't in transit,
	// due for a (probabilistic) update
	// and manage live feeds more granularly across open connections

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	fetchGroup, ctx := errgroup.WithContext(ctx)

	for _, r := range lst {
		fetchGroup.Go(h.workFeed(ctx, e, r, withLive))
	}

	err = fetchGroup.Wait()
	return err
}

func (h *LegacyGossip) workFeed(ctx context.Context, edp muxrpc.Endpoint, ref refs.FeedRef, withLive bool) func() error {
	return func() error {
		err := h.fetchFeed(ctx, ref, edp, time.Now(), withLive)
		var callErr *muxrpc.CallError
		var noSuchMethodErr muxrpc.ErrNoSuchMethod
		if muxrpc.IsSinkClosed(err) ||
			errors.As(err, &noSuchMethodErr) ||
			errors.As(err, &callErr) ||
			errors.Is(err, context.Canceled) ||
			errors.Is(err, muxrpc.ErrSessionTerminated) ||
			neterr.IsConnBrokenErr(err) {
			return err
		} else if err != nil {
			// just logging the error assuming forked feed for instance
			level.Warn(h.Info).Log("event", "skipped updating of stored feed", "err", err, "fr", ref.ShortSigil())
		}

		return nil
	}
}

// fetchFeed requests the feed fr from endpoint e into the repo of the handler
func (h *LegacyGossip) fetchFeed(
	ctx context.Context,
	fr refs.FeedRef,
	edp muxrpc.Endpoint,
	started time.Time,
	withLive bool,
) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// wether to fetch this feed in full (TODO: should be passed in)
	completeFeed := true
	var err error
	snk, err := h.verifyRouter.GetSink(fr, completeFeed)
	if err != nil {
		return fmt.Errorf("failed to get verify sink for feed: %w", err)
	}

	var latestSeq = int(snk.Seq())
	startSeq := latestSeq
	info := log.With(h.Info, "event", "gossiprx",
		"fr", fr.ShortSigil(),
		"starting", latestSeq) // , "me", g.Id.ShortRef())

	var q = message.NewCreateHistoryStreamArgs()
	q.ID = fr
	q.Seq = int64(latestSeq + 1)
	q.Live = withLive

	defer func() {
		if n := latestSeq - startSeq; n > 0 {
			if h.sysGauge != nil {
				h.sysGauge.With("part", "msgs").Add(float64(n))
			}
			if h.sysCtr != nil {
				h.sysCtr.With("event", "gossiprx").Add(float64(n))
			}
			level.Debug(info).Log("received", n, "took", time.Since(started))
		}
	}()

	// level.Info(info).Log("starting", "fetch")
	method := muxrpc.Method{"createHistoryStream"}

	var src *muxrpc.ByteSource
	switch fr.Algo() {
	case refs.RefAlgoFeedSSB1:
		src, err = edp.Source(ctx, muxrpc.TypeJSON, method, q)
	case refs.RefAlgoFeedBendyButt:
		fallthrough
	case refs.RefAlgoFeedGabby:
		src, err = edp.Source(ctx, muxrpc.TypeBinary, method, q)
	default:
		return fmt.Errorf("fetchFeed(%s): unhandled feed format", fr.String())
	}
	if err != nil {
		return fmt.Errorf("fetchFeed(%s:%d) failed to create source: %w", fr.String(), latestSeq, err)
	}

	var buf = &bytes.Buffer{}
	for src.Next(ctx) {

		err = src.Reader(func(r io.Reader) error {
			_, err = buf.ReadFrom(r)
			return err
		})
		if err != nil {
			return err
		}

		err = snk.Verify(buf.Bytes())
		if err != nil {
			return err
		}
		buf.Reset()
		latestSeq++
	}

	if err := src.Err(); err != nil {
		return fmt.Errorf("fetchFeed(%s:%d) gossip pump failed: %w", fr.String(), latestSeq, err)
	}

	return nil
}
