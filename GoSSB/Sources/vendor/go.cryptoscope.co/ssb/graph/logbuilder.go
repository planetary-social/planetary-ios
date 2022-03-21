// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package graph

import (
	"context"
	"fmt"
	"math"
	"time"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	kitlog "go.mindeco.de/log"
	"go.mindeco.de/log/level"
	refs "go.mindeco.de/ssb-refs"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/simple"
	"gonum.org/v1/gonum/graph/traverse"

	"go.cryptoscope.co/ssb"
)

type logBuilder struct {
	logger kitlog.Logger

	contactsLog margaret.Log

	current *Graph

	currentQueryCancel context.CancelFunc
}

// NewLogBuilder is a much nicer abstraction than the direct k:v implementation.
// most likely terribly slow though. Additionally, we have to unmarshal from stored.Raw again...
// TODO: actually compare the two with benchmarks if only to compare the 3rd!
func NewLogBuilder(logger kitlog.Logger, contacts margaret.Log) (*logBuilder, error) {
	lb := logBuilder{
		logger:      logger,
		contactsLog: contacts,
		current:     NewGraph(),
	}

	_, err := lb.Build()
	if err != nil {
		return nil, fmt.Errorf("failed to build graph: %w", err)
	}

	return &lb, nil
}

func (b *logBuilder) Close() error { return nil }

func (b *logBuilder) startQuery(ctx context.Context) {
	src, err := b.contactsLog.Query(margaret.Live(true))
	if err != nil {
		err = fmt.Errorf("failed to make live query for contacts: %w", err)
		level.Error(b.logger).Log("err", err, "event", "query build failed")
		return
	}
	err = luigi.Pump(ctx, luigi.FuncSink(b.buildGraph), src)
	if err != nil {
		level.Error(b.logger).Log("err", err, "event", "graph build failed")
	}
}

// DeleteAuthor just triggers a rebuild (and expects the author to have dissapeard from the message source)
func (b *logBuilder) DeleteAuthor(who refs.FeedRef) error {
	b.current.Lock()
	defer b.current.Unlock()

	b.currentQueryCancel()
	b.current = nil

	ctx, cancel := context.WithCancel(context.Background())
	go b.startQuery(ctx)
	b.currentQueryCancel = cancel

	return nil
}

func (b *logBuilder) Authorizer(from refs.FeedRef, maxHops int) ssb.Authorizer {
	return &authorizer{
		b:       b,
		from:    from,
		maxHops: maxHops,
		log:     b.logger,
	}
}

func (b *logBuilder) Build() (*Graph, error) {
	b.current.Lock()
	defer b.current.Unlock()

	ctx, cancel := context.WithCancel(context.Background())
	go b.startQuery(ctx)
	b.currentQueryCancel = cancel

	time.Sleep(1 * time.Second)
	return b.current, nil
}

func (b *logBuilder) buildGraph(ctx context.Context, v interface{}, err error) error {
	if err != nil {
		if luigi.IsEOS(err) {
			return nil
		}
		return err
	}

	b.current.Lock()
	defer b.current.Unlock()
	dg := b.current.WeightedDirectedGraph

	abs, ok := v.(refs.Message)
	if !ok {
		err := fmt.Errorf("graph/idx: invalid msg value %T", v)
		return err
	}

	var c refs.Contact
	err = c.UnmarshalJSON(abs.ContentBytes())
	if err != nil {
		// ignore invalid messages
		return nil
	}

	author := abs.Author()
	contact := c.Contact

	if author.Equal(contact) {
		// contact self?!
		return nil
	}

	bfrom := storedrefs.Feed(author)
	nFrom, has := b.current.lookup[bfrom]
	if !has {
		nFrom = &contactNode{dg.NewNode(), author, ""}
		dg.AddNode(nFrom)
		b.current.lookup[bfrom] = nFrom
	}

	bto := storedrefs.Feed(contact)
	nTo, has := b.current.lookup[bto]
	if !has {
		nTo = &contactNode{dg.NewNode(), contact, ""}
		dg.AddNode(nTo)
		b.current.lookup[bto] = nTo
	}

	w := math.Inf(-1)
	if c.Following {
		w = 1
	} else if c.Blocking {
		w = math.Inf(1)
	} else if !c.Following && !c.Blocking {
		if dg.HasEdgeFromTo(nFrom.ID(), nTo.ID()) {
			dg.RemoveEdge(nFrom.ID(), nTo.ID())
		}
		return nil
	}

	edg := simple.WeightedEdge{F: nFrom, T: nTo, W: w}
	dg.SetWeightedEdge(contactEdge{
		WeightedEdge: edg,
		isBlock:      c.Blocking,
	})

	return nil
}

func (b *logBuilder) Follows(from refs.FeedRef) (*ssb.StrFeedSet, error) {
	g, err := b.Build()
	if err != nil {
		return nil, fmt.Errorf("follows: couldn't build graph: %w", err)
	}
	fb := storedrefs.Feed(from)
	nFrom, has := g.lookup[fb]
	if !has {
		return nil, ErrNoSuchFrom{from}
	}

	nodes := g.From(nFrom.ID())

	refs := ssb.NewFeedSet(nodes.Len())

	for nodes.Next() {
		cnv := nodes.Node().(*contactNode)
		// warning - ignores edge type!
		edg := g.Edge(nFrom.ID(), cnv.ID())
		if edg.(contactEdge).Weight() == 1 {
			if err := refs.AddRef(cnv.feed); err != nil {
				return nil, err
			}
		}
	}
	return refs, nil
}

func (b *logBuilder) Hops(from refs.FeedRef, max int) *ssb.StrFeedSet {
	g, err := b.Build()
	if err != nil {
		panic(err)
	}
	b.current.Lock()
	defer b.current.Unlock()
	fb := storedrefs.Feed(from)
	nFrom, has := g.lookup[fb]
	if !has {
		fs := ssb.NewFeedSet(1)
		fs.AddRef(from)
		return fs
	}
	// fmt.Println(from.Ref(), max)
	w := traverse.BreadthFirst{
		// only traverse friend edges
		Traverse: func(e graph.Edge) bool {
			ce := e.(contactEdge)
			rev := g.Edge(ce.To().ID(), ce.From().ID())
			if rev == nil {
				return true
			}
			return ce.Weight() == 1 && rev.(contactEdge).Weight() == 1
		},
	}
	fs := ssb.NewFeedSet(10)
	w.Walk(g, nFrom, func(n graph.Node, d int) bool {
		if d > max+1 {
			return true
		}

		// if d >= len(got) {
		// 	got = append(got, []int64(nil))
		// }
		// got[d] = append(got[d], n.ID())

		cn := n.(*contactNode)
		fs.AddRef(cn.feed)
		return false
	})

	// goon.Dump(got)
	// goon.Dump(final)
	return fs
}

func (bld *logBuilder) State(a, b refs.FeedRef) int {
	g, err := bld.Build()
	if err != nil {
		panic(err)
	}
	if g.Blocks(a, b) {
		return -1
	}
	if g.Follows(a, b) {
		return 1
	}
	return 0
}
