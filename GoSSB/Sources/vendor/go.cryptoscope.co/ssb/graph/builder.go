// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package graph

import (
	"bytes"
	"fmt"
	"math"
	"net/http"
	"sync"

	"github.com/dgraph-io/badger/v3"
	librarian "go.cryptoscope.co/margaret/indexes"
	libbadger "go.cryptoscope.co/margaret/indexes/badger"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/path"
	"gonum.org/v1/gonum/graph/simple"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

// Builder can build a trust graph and answer other questions
type Builder interface {

	// Build a complete graph of all follow/block relations
	Build() (*Graph, error)

	// Follows returns a set of all people ref follows
	Follows(refs.FeedRef) (*ssb.StrFeedSet, error)

	// TODO: move this into the graph
	Hops(refs.FeedRef, int) *ssb.StrFeedSet

	Authorizer(from refs.FeedRef, maxHops int) ssb.Authorizer

	DeleteAuthor(who refs.FeedRef) error
}

type IndexingBuilder interface {
	Builder

	OpenIndex() (librarian.SeqSetterIndex, librarian.SinkIndex)
}

// BadgerBuilder can construct a graph from the badger key-value database it was initialized with.
type BadgerBuilder struct {
	kv *badger.DB

	idx librarian.SeqSetterIndex

	idxSinkContacts      librarian.SinkIndex
	idxSinkMetaFeeds     librarian.SinkIndex
	idxSinkAnnouncements librarian.SinkIndex

	log log.Logger

	cacheLock   sync.Mutex
	cachedGraph *Graph

	hmacSecret *[32]byte
}

var (
	dbKeyPrefix    = []byte("trust-graph")
	dbKeyPrefixLen = len(dbKeyPrefix)
)

// NewBuilder creates a Builder that is backed by a badger database
func NewBuilder(log log.Logger, db *badger.DB, hmacSecret *[32]byte) *BadgerBuilder {
	b := &BadgerBuilder{
		kv:  db,
		log: log,

		idx: libbadger.NewIndexWithKeyPrefix(db, 0, dbKeyPrefix),

		hmacSecret: hmacSecret,
	}
	return b
}

func (b *BadgerBuilder) DeleteAuthor(who refs.FeedRef) error {
	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()
	b.cachedGraph = nil
	return b.kv.Update(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		prefix := append(dbKeyPrefix, []byte(storedrefs.Feed(who))...)
		for iter.Seek(prefix); iter.ValidForPrefix(prefix); iter.Next() {
			it := iter.Item()

			k := it.Key()
			if err := txn.Delete(k); err != nil {
				return fmt.Errorf("DeleteAuthor: failed to drop record %x: %w", k, err)
			}
		}
		return nil
	})
}

func (b *BadgerBuilder) Authorizer(from refs.FeedRef, maxHops int) ssb.Authorizer {
	return &authorizer{
		b:       b,
		from:    from,
		maxHops: maxHops,
		log:     b.log,
	}
}

func (b *BadgerBuilder) Build() (*Graph, error) {
	dg := NewGraph()

	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()

	if b.cachedGraph != nil {
		return b.cachedGraph, nil
	}

	err := b.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		for iter.Seek(dbKeyPrefix); iter.ValidForPrefix(dbKeyPrefix); iter.Next() {
			it := iter.Item()
			k := it.Key()
			if len(k) != 68+dbKeyPrefixLen {
				continue
			}

			rawFrom := k[dbKeyPrefixLen : 34+dbKeyPrefixLen]
			rawTo := k[34+dbKeyPrefixLen:]

			if bytes.Equal(rawFrom, rawTo) {
				// contact self?!
				continue
			}

			var to, from tfk.Feed
			if err := from.UnmarshalBinary(rawFrom); err != nil {
				return fmt.Errorf("builder: couldnt idx key value (from): %w", err)
			}
			if err := to.UnmarshalBinary(rawTo); err != nil {
				return fmt.Errorf("builder: couldnt idx key value (to): %w", err)
			}

			bfrom := librarian.Addr(rawFrom)
			nFrom, has := dg.lookup[bfrom]
			if !has {
				fromRef, err := from.Feed()
				if err != nil {
					return err
				}

				nFrom = &contactNode{dg.NewNode(), fromRef, ""}
				dg.AddNode(nFrom)
				dg.lookup[bfrom] = nFrom
			}

			bto := librarian.Addr(rawTo)
			nTo, has := dg.lookup[bto]
			if !has {
				toRef, err := to.Feed()
				if err != nil {
					return err
				}
				nTo = &contactNode{dg.NewNode(), toRef, ""}
				dg.AddNode(nTo)
				dg.lookup[bto] = nTo
			}

			if nFrom.ID() == nTo.ID() {
				continue
			}

			var edg graph.WeightedEdge

			err := it.Value(func(v []byte) error {
				if len(v) >= 1 {
					switch v[0] {
					case '0': // not following
						edg = contactEdge{
							WeightedEdge: simple.WeightedEdge{F: nFrom, T: nTo, W: math.Inf(-1)},
							isBlock:      false,
						}
					case '1': // following
						edg = contactEdge{
							WeightedEdge: simple.WeightedEdge{F: nFrom, T: nTo, W: 1},
							isBlock:      false,
						}
					case '2': // blocking
						edg = contactEdge{
							WeightedEdge: simple.WeightedEdge{F: nFrom, T: nTo, W: math.Inf(1)},
							isBlock:      true,
						}
					case '3': // metafeed
						edg = metafeedEdge{
							WeightedEdge: simple.WeightedEdge{F: nFrom, T: nTo, W: 0.1},
						}
					default:
						return fmt.Errorf("barbage value in graph strore %q", string(v))
					}
				}
				return nil
			})
			if err != nil {
				return fmt.Errorf("failed to get value from item:%q: %w", string(k), err)
			}

			if math.IsInf(edg.Weight(), -1) {
				//dg.RemoveEdge(nFrom.ID(), nTo.ID())
				continue
			}

			dg.SetWeightedEdge(edg)
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

func (l Lookup) Dist(to refs.FeedRef) ([]graph.Node, float64) {
	bto := storedrefs.Feed(to)
	nTo, has := l.lookup[bto]
	if !has {
		return nil, math.Inf(-1)
	}
	return l.dijk.To(nTo.ID())
}

func (b *BadgerBuilder) Follows(forRef refs.FeedRef) (*ssb.StrFeedSet, error) {
	fs := ssb.NewFeedSet(50)
	err := b.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		prefix := append(dbKeyPrefix, storedrefs.Feed(forRef)...)
		for iter.Seek(prefix); iter.ValidForPrefix(prefix); iter.Next() {
			it := iter.Item()
			k := it.Key()

			err := it.Value(func(v []byte) error {
				if len(v) >= 1 && v[0] == '1' {
					// extract 2nd feed ref out of db key
					var sr tfk.Feed
					err := sr.UnmarshalBinary(k[dbKeyPrefixLen+34:])
					if err != nil {
						return fmt.Errorf("follows(%s): invalid ref entry in db for feed: %w", forRef.String(), err)
					}
					fr, err := sr.Feed()
					if err != nil {
						return err
					}
					if err := fs.AddRef(fr); err != nil {
						return fmt.Errorf("follows(%s): couldn't add parsed ref feed: %w", forRef.String(), err)
					}
				}
				return nil
			})
			if err != nil {
				return fmt.Errorf("failed to get value from iter: %w", err)
			}
		}
		return nil
	})
	return fs, err
}

// Metafeed returns the metafeed for a subfeed, or an error if it has none.
func (b *BadgerBuilder) Metafeed(subfeed refs.FeedRef) (refs.FeedRef, error) {
	var found refs.FeedRef
	err := b.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		metafeedEntry := append(dbKeyPrefix, storedrefs.Feed(subfeed)...)
		item, err := txn.Get(metafeedEntry)
		if err != nil {
			return err
		}

		err = item.Value(func(v []byte) error {
			var sr tfk.Feed
			err := sr.UnmarshalBinary(v)
			if err != nil {
				return fmt.Errorf("metafeed(%s): invalid ref entry in db for feed: %w", subfeed.String(), err)
			}
			fr, err := sr.Feed()
			if err != nil {
				return err
			}
			found = fr

			return nil
		})

		return err
	})
	return found, err
}

// Subfeeds returns the set of subfeeds for a particular metafeed.
func (b *BadgerBuilder) Subfeeds(metaFeed refs.FeedRef) (*ssb.StrFeedSet, error) {
	fs := ssb.NewFeedSet(50)
	err := b.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		prefix := append(dbKeyPrefix, storedrefs.Feed(metaFeed)...)
		for iter.Seek(prefix); iter.ValidForPrefix(prefix); iter.Next() {
			it := iter.Item()
			k := it.Key()

			err := it.Value(func(v []byte) error {
				if len(v) >= 1 && v[0] == '3' {
					// extract 2nd feed ref out of db key
					var sr tfk.Feed
					err := sr.UnmarshalBinary(k[dbKeyPrefixLen+34:])
					if err != nil {
						return fmt.Errorf("follows(%s): invalid ref entry in db for feed: %w", metaFeed.String(), err)
					}
					fr, err := sr.Feed()
					if err != nil {
						return err
					}
					if err := fs.AddRef(fr); err != nil {
						return fmt.Errorf("follows(%s): couldn't add parsed ref feed: %w", metaFeed.String(), err)
					}
				}
				return nil
			})
			if err != nil {
				return fmt.Errorf("failed to get value from iter: %w", err)
			}
		}
		return nil
	})
	return fs, err
}

// Hops returns a slice of feed refrences that are in a particulare range of from
//
//    * max == 0: only direct follows of from
//    * max == 1: max:0 + follows of friends of from
//    * max == 2: max:1 + follows of their friends
//
// See hops_test.go for concrete examples.
func (b *BadgerBuilder) Hops(from refs.FeedRef, max int) *ssb.StrFeedSet {
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

func (b *BadgerBuilder) recurseHops(walked *ssb.StrFeedSet, vis map[string]struct{}, who refs.FeedRef, depth int) error {
	if depth <= 0 {
		return nil
	}

	// skip if we already visited this peer
	if _, ok := vis[who.String()]; ok {
		return nil
	}

	// utility function encapsulating logic around recursing subfeeds
	recurseSubfeeds := func(feedId refs.FeedRef) error {
		// find all their subfeeds
		subfeeds, err := b.Subfeeds(feedId)
		if err != nil {
			return fmt.Errorf("recurseHops(%d): couldnt estblish subfeeds for %s: %w", depth, feedId.String(), err)
		}

		// TODO: add iteration to reduce memory overhead of creating a bunch of slices all the time
		// ie. feedset.Each(func(f refs.FeedRef) { ... })
		subfeedList, err := subfeeds.List()
		if err != nil {
			return fmt.Errorf("recurseHops(%d): couldnt list subfeeds for list for %s: %w", depth, feedId.String(), err)
		}

		// add them to the set and recurse their follows
		for j, subfeed := range subfeedList {
			err = walked.AddRef(subfeed)
			if err != nil {
				return fmt.Errorf("recurseHops(%d): add subfeed entry(%d) of %s failed: %w", depth, j, feedId.String(), err)
			}

			// also iterate their follows. same depth because they count as the same identity as the metafeed that linked them
			if err := b.recurseHops(walked, vis, subfeed, depth); err != nil {
				return err
			}
		}
		return nil
	}

	if err := recurseSubfeeds(who); err != nil {
		return err
	}

	whosFollows, err := b.Follows(who)
	if err != nil {
		return fmt.Errorf("recurseHops(%d): follow listing for target failed: %w", depth, err)
	}

	theirFollowList, err := whosFollows.List()
	if err != nil {
		return fmt.Errorf("recurseHops(%d): invalid entry in feed set: %w", depth, err)
	}

	for i, followedByWho := range theirFollowList {
		err := walked.AddRef(followedByWho)
		if err != nil {
			return fmt.Errorf("recurseHops(%d): add list entry(%d) failed: %w", depth, i, err)
		}

		// looking for metafeed of iterated follow
		if mf, err := b.Metafeed(followedByWho); err == nil {
			// add the retrieved metafeed as one of the visited hops (note: it is at distance 0 from its corresponding main feed)
			err := walked.AddRef(mf)
			if err != nil {
				return fmt.Errorf("recurseHops(%d): add metafeed entry(%d) failed: %w", depth, i, err)
			}

			if err := recurseSubfeeds(mf); err != nil {
				return err
			}
		}

		if err := recurseSubfeeds(followedByWho); err != nil {
			return err
		}

		// TODO: use from follows followedByWho
		dstFollows, err := b.Follows(followedByWho)
		if err != nil {
			return fmt.Errorf("recurseHops(%d): follows from entry(%d) failed: %w", depth, i, err)
		}

		isF := dstFollows.Has(who)
		if isF { // found a friend, recurse
			if err := b.recurseHops(walked, vis, followedByWho, depth-1); err != nil {
				return err
			}
		}
		// b.log.Log("depth", depth, "from", from.ShortRef(), "follows", followedByWho.ShortRef(), "friend", isF, "cnt", dstFollows.Count())
	}

	// mark them as visited
	vis[who.String()] = struct{}{}

	return nil
}

func (b *BadgerBuilder) DumpXMLOverHTTP(self refs.FeedRef, w http.ResponseWriter, req *http.Request) {
	hlog := log.With(b.log, "http-handler", req.URL.Path)
	g, err := b.Build()
	if err != nil {
		level.Error(hlog).Log("http-err", err.Error())
		http.Error(w, "graph build failure", http.StatusInternalServerError)
		return
	}

	// initialze new reducer
	var rg graphReducer
	rg.wanted = make(wantedMap)
	rg.graph = simple.NewWeightedDirectedGraph(0, math.Inf(1))

	// find the nodes we are interested in

	selfNode, has := g.getNode(self)
	if !has {
		level.Error(hlog).Log("http-err", "no self node in graph")
		http.Error(w, "graph build failure", http.StatusInternalServerError)
		return
	}
	rg.wanted[selfNode.ID()] = struct{}{}

	hopsSet := b.Hops(self, 1) // TODO: parametize
	hopsList, err := hopsSet.List()
	if err != nil {
		level.Error(hlog).Log("http-err", err.Error())
		http.Error(w, "graph build failure", http.StatusInternalServerError)
		return
	}

	for _, feed := range hopsList {
		node, has := g.getNode(feed)
		if !has {
			continue
		}
		rg.wanted[node.ID()] = struct{}{}
	}

	graph.CopyWeighted(rg, g)

	var smallerGraph = new(Graph)
	smallerGraph.lookup = g.lookup
	smallerGraph.WeightedDirectedGraph = rg.graph

	n := smallerGraph.NodeCount()
	if n > 100 {
		level.Error(hlog).Log("http-err", "too many nodes", "count", n)
		http.Error(w, "too many nodes", http.StatusInternalServerError)
		return
	}

	wh := w.Header()
	wh.Set("Content-Type", "image/svg+xml")
	w.WriteHeader(http.StatusOK)
	err = smallerGraph.RenderSVG(w)
	if err != nil {
		level.Error(hlog).Log("http-err", err.Error())
	}

	level.Info(hlog).Log("graph", "dumped", "nodes", n)
}

type wantedMap map[int64]struct{}

type graphReducer struct {
	graph *simple.WeightedDirectedGraph

	wanted wantedMap
}

// NewNode returns a new Node with a unique
// arbitrary ID.
func (gs graphReducer) NewNode() graph.Node {
	panic("NewNode not supported")
}

// AddNode adds a node to the graph. AddNode panics if
// the added node ID matches an existing node ID.
func (gs graphReducer) AddNode(a graph.Node) {
	if _, has := gs.wanted[a.ID()]; !has {
		return
	}
	gs.graph.AddNode(a)
}

// NewWeightedEdge returns a new WeightedEdge from
// the source to the destination node.
func (gs graphReducer) NewWeightedEdge(from graph.Node, to graph.Node, weight float64) graph.WeightedEdge {
	panic("not implemented") // TODO: Implement
}

// SetWeightedEdge adds an edge from one node to
// another. If the graph supports node addition
// the nodes will be added if they do not exist,
// otherwise SetWeightedEdge will panic.
// The behavior of a WeightedEdgeAdder when the IDs
// returned by e.From() and e.To() are equal is
// implementation-dependent.
// Whether e, e.From() and e.To() are stored
// within the graph is implementation dependent.
func (gs graphReducer) SetWeightedEdge(e graph.WeightedEdge) {
	if _, has := gs.wanted[e.From().ID()]; !has {
		// fmt.Println("ignoring from", e.From().(*contactNode).feed.Ref())
		return
	}

	if _, has := gs.wanted[e.To().ID()]; !has {
		// fmt.Println("ignoring to", e.From().(*contactNode).feed.Ref())
		return
	}

	gs.graph.SetWeightedEdge(e)
}
