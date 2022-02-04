// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package graph derives trust/block relations by consuming type:contact message and offers lookup APIs between two feeds.
package graph

import (
	"math"
	"sync"

	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	refs "go.mindeco.de/ssb-refs"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/path"
	"gonum.org/v1/gonum/graph/simple"
)

type key2node map[librarian.Addr]*contactNode

type Graph struct {
	sync.Mutex
	*simple.WeightedDirectedGraph
	lookup key2node
}

func NewGraph() *Graph {
	return &Graph{
		WeightedDirectedGraph: simple.NewWeightedDirectedGraph(0, math.Inf(1)),
		lookup:                make(key2node),
	}
}

func (g *Graph) getNode(feed refs.FeedRef) (*contactNode, bool) {
	node, has := g.lookup[storedrefs.Feed(feed)]
	if !has {
		return nil, false
	}
	return node, true
}

func (g *Graph) getEdge(from, to refs.FeedRef) (graph.WeightedEdge, bool) {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	nFrom, has := g.lookup[storedrefs.Feed(from)]
	if !has {
		return nil, false
	}
	nTo, has := g.lookup[storedrefs.Feed(to)]
	if !has {
		return nil, false
	}
	if !g.HasEdgeFromTo(nFrom.ID(), nTo.ID()) {
		return nil, false
	}
	edg := g.Edge(nFrom.ID(), nTo.ID())
	return edg.(graph.WeightedEdge), true
}

func (g *Graph) Follows(from, to refs.FeedRef) bool {
	w, has := g.getEdge(from, to)
	if !has {
		return false
	}
	return w.Weight() == 1
}

func (g *Graph) Blocks(from, to refs.FeedRef) bool {
	w, has := g.getEdge(from, to)
	if !has {
		return false
	}
	return math.IsInf(w.Weight(), 1)
}

func (g *Graph) Subfeed(from, to refs.FeedRef) bool {
	w, has := g.getEdge(from, to)
	if !has {
		return false
	}
	return w.Weight() == 0.1
}

func (g *Graph) BlockedList(from refs.FeedRef) *ssb.StrFeedSet {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	blocked := ssb.NewFeedSet(0)
	nFrom, has := g.lookup[storedrefs.Feed(from)]
	if !has {
		return blocked
	}
	fromID := nFrom.ID()
	edgs := g.From(fromID)
	for edgs.Next() {
		nTo := edgs.Node()
		edg := g.Edge(fromID, nTo.ID()).(graph.WeightedEdge)
		//	if edg.isBlock {
		if math.IsInf(edg.Weight(), 1) {
			ctNode := nTo.(*contactNode)
			blocked.AddRef(ctNode.feed)
		}
	}
	return blocked
}

func (g *Graph) MakeDijkstra(from refs.FeedRef) (*Lookup, error) {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	nFrom, has := g.lookup[storedrefs.Feed(from)]
	if !has {
		return nil, ErrNoSuchFrom{Who: from}
	}
	return &Lookup{
		path.DijkstraFrom(nFrom, g),
		g.lookup,
	}, nil
}
