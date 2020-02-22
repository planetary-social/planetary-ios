// SPDX-License-Identifier: MIT

package gossip

import (
	"context"
	"fmt"
	"sync"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/muxrpc/codec"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/message"
)

// pullManager can be queried for feeds that should be requested from an endpoint
type pullManager struct {
	self      ssb.FeedRef // whoami
	gb        graph.Builder
	feedIndex multilog.MultiLog

	receiveLog margaret.Log
	append     luigi.Sink

	verifyMu    *sync.Mutex
	verifySinks map[string]luigi.Sink

	hops    int
	hmacKey *[32]byte

	logger log.Logger
}

type rxSink struct {
	mu     sync.Mutex
	logger log.Logger
	append margaret.Log
}

func (snk *rxSink) Pour(ctx context.Context, val interface{}) error {
	snk.mu.Lock()
	_, err := snk.append.Append(val)
	if err != nil {
		snk.mu.Unlock()
		return errors.Wrap(err, "failed to append verified message to rootLog")
	}
	// msg := val.(ssb.Message)
	// level.Warn(snk.logger).Log("receivedAsSeq", rxSeq.Seq(), "msgSeq", msg.Seq(), "author", msg.Author().Ref()[1:5])
	snk.mu.Unlock()
	return nil
}

func (snk *rxSink) Close() error { return nil }

func (pull *pullManager) RequestFeeds(ctx context.Context, edp muxrpc.Endpoint) {
	hops := pull.gb.Hops(&pull.self, pull.hops)
	if hops == nil {
		level.Warn(pull.logger).Log("event", "nil hops set")
		return
	}

	hopsLst, err := hops.List()
	if err != nil {
		level.Error(pull.logger).Log("event", "broken hops set", "err", err)
		return
	}

	for _, ref := range hopsLst {
		latestSeq, latestMsg, err := pull.getLatestSeq(ref)
		if err != nil {
			level.Error(pull.logger).Log("event", "failed to get sequence for feed", "err", err, "fr", ref.Ref()[1:5])
			return
		}

		// prepare query arguments for rpc call
		method := muxrpc.Method{"createHistoryStream"}
		var q = message.CreateHistArgs{
			ID:         ref,
			Seq:        int64(latestSeq.Seq() + 1),
			StreamArgs: message.StreamArgs{Limit: -1},
			CommonArgs: message.CommonArgs{Live: true},
		}

		// one sink per feed
		pull.verifyMu.Lock()
		verifySink, has := pull.verifySinks[ref.Ref()]
		if !has {
			verifySink = message.NewVerifySink(ref, latestSeq, latestMsg, pull.append, pull.hmacKey)
			verifySink = lockedSink(verifySink)
			pull.verifySinks[ref.Ref()] = verifySink
		}
		pull.verifyMu.Unlock()

		// unwrap the codec packet for the SunkenSource call and forward it to the verifySink
		storeSnk := luigi.FuncSink(func(ctx context.Context, val interface{}, err error) error {
			if err != nil {
				if luigi.IsEOS(err) {
					return nil
				}
				return err
			}
			pkt, ok := val.(*codec.Packet)
			if !ok {
				return errors.Errorf("muxrpc: unexpected codec value: %T", val)
			}

			if pkt.Flag.Get(codec.FlagEndErr) {
				return luigi.EOS{}
			}

			if !pkt.Flag.Get(codec.FlagStream) {
				return errors.Errorf("pullManager: expected stream packet")
			}

			if err := verifySink.Pour(ctx, pkt.Body); err != nil {
				level.Warn(pull.logger).Log("event", "msg-verify", "err", err)
				return luigi.EOS{}
			}

			return nil
		})

		err = edp.SunkenSource(ctx, storeSnk, method, q)
		if err != nil && !muxrpc.IsSinkClosed(err) {
			err = errors.Wrapf(err, "fetchFeed(%s:%d) failed to create source", ref.Ref(), latestSeq.Seq())
			level.Error(pull.logger).Log("event", "create source", "err", err)
			return
		}
	}
	// level.Debug(pull.logger).Log("msg", "pull inited", "count", hops.Count(), "took", time.Since(start))
}

func (pull pullManager) getLatestSeq(fr *ssb.FeedRef) (margaret.Seq, ssb.Message, error) {
	feed, err := pull.feedIndex.Get(fr.StoredAddr())
	if err != nil {
		return nil, nil, errors.Wrapf(err, "failed to open sublog for user")
	}
	latest, err := feed.Seq().Value()
	if err != nil {
		return nil, nil, errors.Wrapf(err, "failed to observe latest")
	}

	currSeq, ok := latest.(margaret.BaseSeq)
	if !ok {
		return nil, nil, errors.Errorf("pullManager: unexpected type in sequence log: %T", latest)
	}

	if currSeq == margaret.SeqEmpty {
		return margaret.BaseSeq(0), nil, nil
	}

	rootLogValue, err := feed.Get(currSeq)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "failed to look up root seq for latest user sublog")
	}

	rootLogSeq, ok := rootLogValue.(margaret.Seq)
	if !ok {
		return nil, nil, errors.Errorf("pullManager: unexpected type in sublog: %T", rootLogValue)
	}

	msgV, err := pull.receiveLog.Get(rootLogSeq)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "failed retreive stored message")
	}

	latestMsg, ok := msgV.(ssb.Message)
	if !ok {
		return nil, nil, errors.Errorf("fetch: wrong message type. expected %T - got %T", latestMsg, msgV)
	}

	// sublog is 0-init while ssb chains start at 1
	var latestSeq margaret.BaseSeq = currSeq + 1

	// make sure our house is in order
	if hasSeq := latestMsg.Seq(); hasSeq != latestSeq.Seq() {
		return nil, nil, ssb.ErrWrongSequence{
			Ref:     fr,
			Stored:  latestMsg,
			Logical: latestSeq}
	}

	return latestSeq, latestMsg, nil
}

func lockedSink(sink luigi.Sink) luigi.Sink {
	var l sync.Mutex

	return luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		l.Lock()
		defer l.Unlock()

		if err != nil {
			cwe, ok := sink.(interface{ CloseWithError(error) error })
			if ok {
				return cwe.CloseWithError(err)
			}

			if err != (luigi.EOS{}) {
				fmt.Printf("was closed with error %q but underlying sink can not be closed with error\n", err)
			}

			return sink.Close()
		}

		return sink.Pour(ctx, v)
	})
}
