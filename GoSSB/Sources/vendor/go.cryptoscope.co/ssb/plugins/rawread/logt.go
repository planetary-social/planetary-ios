// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package rawread

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"time"

	bmap "github.com/dgraph-io/sroar"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog/roaring"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/muxrpc/v2/typemux"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/mutil"
	"go.cryptoscope.co/ssb/internal/transform"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/private"
	"go.cryptoscope.co/ssb/repo"
)

type Plugin struct {
	rxlog margaret.Log
	types *roaring.MultiLog

	priv    *roaring.MultiLog
	isSelf  ssb.Authorizer
	unboxer *private.Manager

	res *repo.SequenceResolver

	h muxrpc.Handler

	info log.Logger
}

func NewByTypePlugin(
	log log.Logger,
	rootLog margaret.Log,
	tl *roaring.MultiLog,
	pl *roaring.MultiLog,
	pm *private.Manager,
	res *repo.SequenceResolver,
	isSelf ssb.Authorizer,
) ssb.Plugin {
	plug := &Plugin{
		rxlog: rootLog,
		types: tl,

		priv: pl,

		unboxer: pm,

		res: res,

		isSelf: isSelf,

		info: log,
	}

	h := typemux.New(log)
	h.RegisterSource(muxrpc.Method{"messagesByType"}, plug)

	plug.h = &h
	return plug
}

func (lt Plugin) Name() string            { return "msgTypes" }
func (Plugin) Method() muxrpc.Method      { return muxrpc.Method{"messagesByType"} }
func (lt Plugin) Handler() muxrpc.Handler { return lt.h }

func (g Plugin) HandleSource(ctx context.Context, req *muxrpc.Request, w *muxrpc.ByteSink) error {
	var (
		start  = time.Now()
		logger = log.With(g.info, "method", "messagesByType")
		qry    message.MessagesByTypeArgs
		args   []message.MessagesByTypeArgs
	)

	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		// assume just string for type
		var args []string
		err := json.Unmarshal(req.RawArgs, &args)
		if err != nil {
			return fmt.Errorf("byType: bad request data: %w", err)
		}
		if len(args) != 1 {
			return fmt.Errorf("byType: bad request data: assumed string argument for type field")
		}
		qry.Type = args[0]
		// Defaults for no arguments
		qry.Keys = true
		qry.Limit = -1

	} else {
		nargs := len(args)
		if nargs == 1 {
			qry = args[0]
		} else {
			return fmt.Errorf("byType: bad request data: assumed one argument object but got %d", nargs)
		}
	}

	remote, err := ssb.GetFeedRefFromAddr(req.RemoteAddr())
	if err != nil {
		return fmt.Errorf("failed to establish remote: %w", err)
	}

	isSelf := g.isSelf.Authorize(remote)
	if qry.Private && isSelf != nil {
		return fmt.Errorf("not authroized")
	}

	logger = log.With(logger, "type", qry.Type)

	// create toJSON sink
	snk := transform.NewKeyValueWrapper(w, qry.Keys)

	// wrap it into a counter for debugging
	var cnt int
	snk = newSinkCounter(&cnt, snk)

	idxAddr := librarian.Addr("string:" + qry.Type)
	if qry.Live {
		if qry.Private {
			return fmt.Errorf("TODO: fix live && private")
		}
		typed, err := g.types.Get(idxAddr)
		if err != nil {
			return fmt.Errorf("failed to load typed log: %w", err)
		}

		src, err := mutil.Indirect(g.rxlog, typed).Query(
			margaret.Limit(int(qry.Limit)),
			margaret.Live(qry.Live))
		if err != nil {
			return fmt.Errorf("logT: failed to qry tipe: %w", err)
		}

		// if qry.Private { TODO
		// 	src = g.unboxedSrc(src)
		// g.unboxer.WrappedUnboxingSink(snk)
		// }

		err = luigi.Pump(ctx, snk, src)
		if err != nil {
			return fmt.Errorf("logT: failed to pump msgs: %w", err)
		}

		return snk.Close()
	}

	/* TODO: i'm skipping a fairly big refactor here to find out what works first.
	   ideallly the live and not-live code would just be the same, somehow shoving it into Query(...).
	   Same goes for timestamp sorting and private.
	   Private is at least orthogonal, whereas sorting and live don't go well together.
	*/

	// not live
	typed, err := g.types.LoadInternalBitmap(idxAddr)
	if err != nil {
		level.Warn(g.info).Log("event", "failed to load type bitmap", "err", err)
		return snk.Close()
	}

	if qry.Private {
		snk = g.unboxer.WrappedUnboxingSink(snk)
	} else {
		// filter all boxed messages from the stream
		box1, err := g.priv.LoadInternalBitmap(librarian.Addr("meta:box1"))
		if err != nil {
			// TODO: compare not found
			// return errors.Wrap(err, "failed to load bmap for box1")
			box1 = bmap.NewBitmap()
		}

		box2, err := g.priv.LoadInternalBitmap(librarian.Addr("meta:box2"))
		if err != nil {
			// TODO: compare not found
			// return errors.Wrap(err, "failed to load bmap for box2")
			box2 = bmap.NewBitmap()
		}

		box1.Or(box2) // all the boxed messages

		// remove all the boxed ones from the type we are looking up
		it := box1.NewIterator()
		for it.HasNext() {
			it.Next()
			v := it.Val()
			if typed.Contains(v) {
				typed.Remove(v)
			}
		}
	}

	// TODO: set _all_ correctly if gt=0 && lt=0
	if qry.Lt == 0 {
		qry.Lt = math.MaxInt64
	}

	var filter = func(ts int64) bool {
		isGreater := ts > int64(qry.Gt)
		isSmaller := ts < int64(qry.Lt)
		return isGreater && isSmaller
	}

	sort, err := g.res.SortAndFilterBitmap(typed, repo.SortByClaimed, filter, qry.Reverse)
	if err != nil {
		return fmt.Errorf("failed to filter bitmap: %w", err)
	}

	sorted := time.Now()
	level.Debug(logger).Log("event", "sorted seqs", "n", len(sort), "took", time.Since(start))

	for _, res := range sort {
		v, err := g.rxlog.Get(int64(res.Seq))
		if err != nil {
			if margaret.IsErrNulled(err) {
				continue
			}
			level.Warn(logger).Log("event", " failed to get seq", "seq", res.Seq, "err", err)
			continue
		}

		if err := snk.Pour(ctx, v); err != nil {
			level.Warn(logger).Log("event", "messagesByType failed to send", "seq", res.Seq, "err", err)
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

func newSinkCounter(counter *int, sink luigi.Sink) luigi.FuncSink {
	return func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			return err
		}

		*counter++
		return sink.Pour(ctx, v)
	}
}
