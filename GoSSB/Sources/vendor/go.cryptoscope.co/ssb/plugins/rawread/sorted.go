// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package rawread

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/muxrpc/v2/typemux"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/transform"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/repo"
)

// ~> sbot createFeedStream --help
// (log) Fetch messages ordered by the time received.
// log [--live] [--gt ts] [--lt ts] [--reverse]  [--keys] [--limit n]
type sortedPlug struct {
	info log.Logger

	root margaret.Log
	res  *repo.SequenceResolver

	h muxrpc.Handler
}

func NewSortedStream(log log.Logger, rootLog margaret.Log, res *repo.SequenceResolver) ssb.Plugin {
	plug := &sortedPlug{
		root: rootLog,
		res:  res,
		info: log,
	}

	h := typemux.New(log)

	h.RegisterSource(muxrpc.Method{"createFeedStream"}, plug)

	plug.h = &h

	return plug
}

func (lt sortedPlug) Name() string            { return "createFeedStream" }
func (sortedPlug) Method() muxrpc.Method      { return muxrpc.Method{"createFeedStream"} }
func (lt sortedPlug) Handler() muxrpc.Handler { return lt.h }

func (g sortedPlug) HandleSource(ctx context.Context, req *muxrpc.Request, snk *muxrpc.ByteSink) error {
	var (
		logger = log.With(g.info, "method", "messagesByType")
		start  = time.Now()
		args   []json.RawMessage
	)
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return fmt.Errorf("bad request data: %w", err)
	}
	var qry message.CreateLogArgs
	if len(args) == 1 {
		err := json.Unmarshal(args[0], &qry)
		if err != nil {
			return fmt.Errorf("bad request data: %w", err)
		}
	} else {
		// Defaults for no arguments
		qry.Keys = true
		qry.Limit = -1
	}

	// empty query doesn't make much sense...
	if qry.Limit == 0 {
		qry.Limit = -1
	}

	// TODO: only return message keys
	// qry.Values = true

	sortedSeqs, err := g.res.SortAndFilterAll(repo.SortByClaimed, func(ts int64) bool {
		isGreater := ts > int64(qry.Gt)
		isSmaller := ts < int64(qry.Lt)
		return isGreater && isSmaller
	}, true)
	if err != nil {
		return err
	}

	sorted := time.Now()
	level.Debug(logger).Log("event", "sorted seqs", "n", len(sortedSeqs), "took", time.Since(start))

	toJSON := transform.NewKeyValueWrapper(snk, qry.Keys)

	// wrap it into a counter for debugging
	var cnt int
	sender := newSinkCounter(&cnt, toJSON)

	for _, res := range sortedSeqs {
		v, err := g.root.Get(int64(res.Seq))
		if err != nil {
			level.Warn(logger).Log("event", "failed to get seq", "seq", res.Seq, "err", err)
			continue
		}

		if err := sender.Pour(ctx, v); err != nil {
			level.Warn(logger).Log("event", "failed to send", "seq", res.Seq, "err", err)
			break
		}

		if qry.Limit >= 0 {
			qry.Limit--
			if qry.Limit == 0 {
				break
			}
		}
	}

	level.Debug(logger).Log("event", "messages streamed", "cnt", cnt, "took", time.Since(sorted))
	return snk.Close()
}
