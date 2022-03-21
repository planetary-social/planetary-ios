// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package graph

import (
	"fmt"
	"math"

	"go.cryptoscope.co/ssb"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	refs "go.mindeco.de/ssb-refs"
)

type authorizer struct {
	b       Builder
	from    refs.FeedRef
	maxHops int
	log     log.Logger
}

// ErrNoSuchFrom should only happen if you reconstruct your existing log from the network
type ErrNoSuchFrom struct {
	Who refs.FeedRef
}

func (nsf ErrNoSuchFrom) Error() string {
	return fmt.Sprintf("ssb/graph: no such from: %s", nsf.Who.String())
}

func (a *authorizer) Authorize(to refs.FeedRef) error {
	fg, err := a.b.Build()
	if err != nil {
		return fmt.Errorf("graph/Authorize: failed to make friendgraph: %w", err)
	}

	if fg.NodeCount() == 0 {
		level.Warn(a.log).Log("msg", "authbypass - trust on first use")
		return nil
	}

	if fg.Follows(a.from, to) {
		// a.log.Log("debug", "following") //, "ref", to.Ref())
		return nil
	}

	// TODO we need to check that `from` is in the graph, instead of checking if it's empty
	// only important in the _resync existing feed_ case. should maybe not construct this authorizer then?
	var distLookup *Lookup
	distLookup, err = fg.MakeDijkstra(a.from)
	if err != nil {
		return fmt.Errorf("graph/Authorize: failed to construct dijkstra: %w", err)
	}

	// dist includes start and end of the path so Alice to Bob will be
	// p:=[Alice, some, friends, Bob]
	// len(p) == 4
	p, d := distLookup.Dist(to)
	hops := len(p) - 2
	if math.IsInf(d, -1) || math.IsInf(d, 1) || hops < 0 || hops > a.maxHops {
		// d == -Inf: peer not connected to the graph
		// d == +Inf: peer directly blocked
		//level.Debug(a.log).Log("event", "out-of-reach", "d", d, "p", fmt.Sprintf("%v", p), "to", to.ShortRef())
		return &ssb.ErrOutOfReach{Dist: hops, Max: a.maxHops}
	}
	return nil

}
