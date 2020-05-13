package sbot

import (
	"fmt"
	"time"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
)

var _ ssb.Replicator = (*Sbot)(nil)

type replicator struct {
	builder graph.Builder

	updateTicker *time.Ticker
	current      *lister
}

func (s *Sbot) newGraphReplicator() (*replicator, error) {
	var r replicator
	r.builder = s.GraphBuilder

	// init graph and fill
	var lis lister
	lis.feedWants = r.builder.Hops(s.KeyPair.Id, int(s.hopCount))
	level.Warn(s.info).Log("event", "replicate", "want", lis.feedWants.Count(), "hops", s.hopCount)
	g, err := r.builder.Build()
	if err != nil {
		return nil, err
	}
	lis.blocked = g.BlockedList(s.KeyPair.Id)

	r.current = &lis

	// TODO: make a smarter update mechanism
	r.updateTicker = time.NewTicker(time.Minute * 10)
	go func() {

		for {
			select {
			case <-r.updateTicker.C:
			case <-s.rootCtx.Done():
				return
			}
			newWants := r.builder.Hops(s.KeyPair.Id, int(s.hopCount))

			refs, err := newWants.List()
			if err != nil {
				level.Error(s.info).Log("event", "replicate", "err", err, "wants", newWants.Count())
				continue
			}
			for _, ref := range refs {
				r.current.feedWants.AddRef(ref)
			}

			// make sure we dont fetch and allow blocked feeds
			g, err := r.builder.Build()
			if err != nil {
				continue
			}

			lis.blocked = g.BlockedList(s.KeyPair.Id)
			lst, err := lis.blocked.List()
			if err == nil {
				for _, bf := range lst {
					r.current.feedWants.Delete(bf)
				}
			}

		}
	}()

	return &r, nil
}

func (r *replicator) Block(ref *ssb.FeedRef)   { r.current.blocked.AddRef(ref) }
func (r *replicator) Unblock(ref *ssb.FeedRef) { r.current.blocked.Delete(ref) }

func (r *replicator) Replicate(ref *ssb.FeedRef)     { r.current.feedWants.AddRef(ref) }
func (r *replicator) DontReplicate(ref *ssb.FeedRef) { r.current.feedWants.Delete(ref) }

func (r *replicator) makeLister() ssb.ReplicationLister { return r.current }

type lister struct {
	feedWants *ssb.StrFeedSet
	blocked   *ssb.StrFeedSet
}

func (l lister) Authorize(remote *ssb.FeedRef) error {
	if l.blocked.Has(remote) {
		return fmt.Errorf("peer blocked")
	}

	if l.feedWants.Has(remote) {
		return nil
	}
	return errors.New("nope - access denied")
}

func (l lister) ReplicationList() *ssb.StrFeedSet { return l.feedWants }
func (l lister) BlockList() *ssb.StrFeedSet       { return l.blocked }
