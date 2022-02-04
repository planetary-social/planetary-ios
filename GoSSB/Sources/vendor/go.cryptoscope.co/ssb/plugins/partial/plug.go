// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package partial is a helper module for ssb-browser-core, enabling to fetch subsets of feeds.
// See https://github.com/arj03/ssb-partial-replication for more.
package partial

import (
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog/roaring"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/muxrpc/v2/typemux"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/plugins/gossip"
	"go.cryptoscope.co/ssb/query"
)

type plugin struct {
	h muxrpc.Handler
}

const name = "partialReplication"

func (p plugin) Name() string {
	return name
}

func (p plugin) Method() muxrpc.Method {
	return muxrpc.Method{name}
}

func (p plugin) Handler() muxrpc.Handler {
	return p.h
}

func New(log logging.Interface,
	fm *gossip.FeedManager,
	feeds, bytype, roots *roaring.MultiLog,
	rxlog margaret.Log,
	get ssb.Getter,
) ssb.Plugin {
	rootHdlr := typemux.New(log)

	rootHdlr.RegisterAsync(muxrpc.Method{name, "getTangle"}, getTangleHandler{
		roots: roots,
		get:   get,
		rxlog: rxlog,
	})

	rootHdlr.RegisterSource(muxrpc.Method{name, "getSubset"}, getSubsetHandler{
		queryPlaner: query.NewSubsetPlaner(feeds, bytype),
		rxLog:       rxlog,
	})

	// TODO:
	// rootHdlr.RegisterSource(muxrpc.Method{name, "resolveIndexFeed"}, getFeedReverseHandler{
	// 	fm: fm,
	// })

	return plugin{
		h: &rootHdlr,
	}
}
