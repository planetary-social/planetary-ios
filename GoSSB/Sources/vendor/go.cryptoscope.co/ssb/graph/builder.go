// SPDX-License-Identifier: MIT

package graph

import (
	"bytes"
	"context"
	"math"
	"sync"

	"github.com/dgraph-io/badger"
	kitlog "github.com/go-kit/kit/log"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	libbadger "go.cryptoscope.co/librarian/badger"
	"go.cryptoscope.co/margaret"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/path"
	"gonum.org/v1/gonum/graph/simple"

	"go.cryptoscope.co/ssb"
)

// Builder can build a trust graph and answer other questions
type Builder interface {

	// Build a complete graph of all follow/block relations
	Build() (*Graph, error)

	// Follows returns a set of all people ref follows
	Follows(*ssb.FeedRef) (*ssb.StrFeedSet, error)

	Hops(*ssb.FeedRef, int) *ssb.StrFeedSet

	Authorizer(from *ssb.FeedRef, maxHops int) ssb.Authorizer

	DeleteAuthor(who *ssb.FeedRef) error
}

type IndexingBuilder interface {
	Builder

	OpenIndex() (librarian.SeqSetterIndex, librarian.SinkIndex)
}

type builder struct {
	kv *badger.DB

	idx     librarian.SeqSetterIndex
	idxSink librarian.SinkIndex

	log kitlog.Logger

	cacheLock   sync.Mutex
	cachedGraph *Graph
}

// NewBuilder creates a Builder that is backed by a badger database
func NewBuilder(log kitlog.Logger, db *badger.DB) *builder {
	b := &builder{
		kv:  db,
		idx: libbadger.NewIndex(db, 0),
		log: log,
	}
	return b
}

func (b *builder) indexUpdateFunc(ctx context.Context, seq margaret.Seq, val interface{}, idx librarian.SetterIndex) error {
	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()

	if nulled, ok := val.(error); ok {
		if margaret.IsErrNulled(nulled) {
			return nil
		}
		return nulled
	}

	abs, ok := val.(ssb.Message)
	if !ok {
		err := errors.Errorf("graph/idx: invalid msg value %T", val)
		b.log.Log("msg", "contact eval failed", "reason", err)
		return err
	}

	var c ssb.Contact
	err := c.UnmarshalJSON(abs.ContentBytes())
	if err != nil {
		// just ignore invalid messages, nothing to do with them (unless you are debugging something)
		//level.Warn(b.log).Log("msg", "skipped contact message", "reason", err)
		return nil
	}

	addr := abs.Author().StoredAddr()
	addr += c.Contact.StoredAddr()
	switch {
	case c.Following:
		err = idx.Set(ctx, addr, 1)
	case c.Blocking:
		err = idx.Set(ctx, addr, 2)
	default:
		err = idx.Set(ctx, addr, 0)
		// cryptix: not sure why this doesn't work
		// it also removes the node if this is the only follow from that peer
		// 3 state handling seems saner
		// err = idx.Delete(ctx, librarian.Addr(addr))
	}
	if err != nil {
		return errors.Wrapf(err, "db/idx contacts: failed to update index. %+v", c)
	}

	b.cachedGraph = nil
	// TODO: patch existing graph instead of invalidating
	return nil
}

func (b *builder) OpenIndex() (librarian.SeqSetterIndex, librarian.SinkIndex) {
	if b.idxSink == nil {
		b.idxSink = librarian.NewSinkIndex(b.indexUpdateFunc, b.idx)
	}
	return b.idx, b.idxSink
}

func (b *builder) DeleteAuthor(who *ssb.FeedRef) error {
	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()
	b.cachedGraph = nil
	return b.kv.Update(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		prefix := []byte(who.StoredAddr())
		for iter.Seek(prefix); iter.ValidForPrefix(prefix); iter.Next() {
			it := iter.Item()

			k := it.Key()
			if err := txn.Delete(k); err != nil {
				return errors.Wrapf(err, "DeleteAuthor: failed to drop record %x", k)
			}
		}
		return nil
	})
}

func (b *builder) Authorizer(from *ssb.FeedRef, maxHops int) ssb.Authorizer {
	return &authorizer{
		b:       b,
		from:    from,
		maxHops: maxHops,
		log:     b.log,
	}
}

func (b *builder) Build() (*Graph, error) {
	dg := NewGraph()

	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()

	if b.cachedGraph != nil {
		return b.cachedGraph, nil
	}

	err := b.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		for iter.Rewind(); iter.Valid(); iter.Next() {
			it := iter.Item()
			k := it.Key()
			if len(k) != 66 {
				continue
			}

			rawFrom := k[:33]
			rawTo := k[33:]

			if bytes.Equal(rawFrom, rawTo) {
				// contact self?!
				continue
			}

			var to, from ssb.StorageRef
			if err := from.Unmarshal(rawFrom); err != nil {
				return errors.Wrapf(err, "builder: couldnt idx key value (from)")
			}
			if err := to.Unmarshal(rawTo); err != nil {
				return errors.Wrap(err, "builder: couldnt idx key value (to)")
			}

			bfrom := librarian.Addr(rawFrom)
			nFrom, has := dg.lookup[bfrom]
			if !has {
				fromRef, err := from.FeedRef()
				if err != nil {
					return err
				}

				nFrom = &contactNode{dg.NewNode(), fromRef.Copy(), ""}
				dg.AddNode(nFrom)
				dg.lookup[bfrom] = nFrom
			}

			bto := librarian.Addr(rawTo)
			nTo, has := dg.lookup[bto]
			if !has {
				toRef, err := to.FeedRef()
				if err != nil {
					return err
				}
				nTo = &contactNode{dg.NewNode(), toRef.Copy(), ""}
				dg.AddNode(nTo)
				dg.lookup[bto] = nTo
			}

			if nFrom.ID() == nTo.ID() {
				continue
			}

			w := math.Inf(-1)
			err := it.Value(func(v []byte) error {
				if len(v) >= 1 {
					switch v[0] {
					case '0': // not following
					case '1':
						w = 1
					case '2':
						w = math.Inf(1)
					default:
						return errors.Errorf("barbage value in graph strore")
					}
				}
				return nil
			})
			if err != nil {
				return errors.Wrapf(err, "failed to get value from item:%q", string(k))
			}

			if math.IsInf(w, -1) {
				//dg.RemoveEdge(nFrom.ID(), nTo.ID())
				continue
			}

			dg.SetWeightedEdge(contactEdge{
				WeightedEdge: simple.WeightedEdge{F: nFrom, T: nTo, W: w},
				isBlock:      math.IsInf(w, 1),
			})
		}
		return nil
	})

	b.cachedGraph = dg
	return dg, err
}

type Lookup struct {
	dijk   path.Shortest
	lookup key2node
}

func (l Lookup) Dist(to *ssb.FeedRef) ([]graph.Node, float64) {
	bto := to.StoredAddr()
	nTo, has := l.lookup[bto]
	if !has {
		return nil, math.Inf(-1)
	}
	return l.dijk.To(nTo.ID())
}

func (b *builder) Follows(forRef *ssb.FeedRef) (*ssb.StrFeedSet, error) {
	if forRef == nil {
		panic("nil feed ref")
	}
	fs := ssb.NewFeedSet(50)
	err := b.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		prefix := []byte(forRef.StoredAddr())
		for iter.Seek(prefix); iter.ValidForPrefix(prefix); iter.Next() {
			it := iter.Item()
			k := it.Key()

			err := it.Value(func(v []byte) error {
				if len(v) >= 1 && v[0] == '1' {
					// extract 2nd feed ref out of db key
					// TODO: use compact StoredAddr
					var sr ssb.StorageRef
					err := sr.Unmarshal(k[33:])
					if err != nil {
						return errors.Wrapf(err, "follows(%s): invalid ref entry in db for feed", forRef.Ref())
					}
					if err := fs.AddStored(&sr); err != nil {
						return errors.Wrapf(err, "follows(%s): couldn't add parsed ref feed", forRef.Ref())
					}
				}
				return nil
			})
			if err != nil {
				return errors.Wrap(err, "failed to get value from iter")
			}
		}
		return nil
	})
	return fs, err
}

// Hops returns a slice of feed refrences that are in a particulare range of from
// max == 0: only direct follows of from
// max == 1: max:0 + follows of friends of from
// max == 2: max:1 + follows of their friends
func (b *builder) Hops(from *ssb.FeedRef, max int) *ssb.StrFeedSet {
	max++
	walked := ssb.NewFeedSet(0)
	visited := make(map[string]struct{}) // tracks the nodes we already recursed from (so we don't do them multiple times on common friends)
	err := b.recurseHops(walked, visited, from, max)
	if err != nil {
		b.log.Log("event", "error", "msg", "recurse failed", "err", err)
		return nil
	}
	walked.Delete(from)
	return walked
}

func (b *builder) recurseHops(walked *ssb.StrFeedSet, vis map[string]struct{}, from *ssb.FeedRef, depth int) error {
	if depth == 0 {
		return nil
	}

	if _, ok := vis[from.Ref()]; ok {
		return nil
	}

	fromFollows, err := b.Follows(from)
	if err != nil {
		return errors.Wrapf(err, "recurseHops(%d): from follow listing failed", depth)
	}

	followLst, err := fromFollows.List()
	if err != nil {
		return errors.Wrapf(err, "recurseHops(%d): invalid entry in feed set", depth)
	}

	for i, followedByFrom := range followLst {
		err := walked.AddRef(followedByFrom)
		if err != nil {
			return errors.Wrapf(err, "recurseHops(%d): add list entry(%d) failed", depth, i)
		}

		dstFollows, err := b.Follows(followedByFrom)
		if err != nil {
			return errors.Wrapf(err, "recurseHops(%d): follows from entry(%d) failed", depth, i)
		}

		isF := dstFollows.Has(from)
		if isF { // found a friend, recurse
			if err := b.recurseHops(walked, vis, followedByFrom, depth-1); err != nil {
				return err
			}
		}
		// b.log.Log("depth", depth, "from", from.ShortRef(), "follows", followedByFrom.ShortRef(), "friend", isF, "cnt", dstFollows.Count())
	}

	vis[from.Ref()] = struct{}{}

	return nil
}
