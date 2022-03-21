// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package friends supplies some of npm:ssb-friends, namly isFollowing, isBlocking and hops but not hopStream, onEdge or createLayer.
package friends

import (
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/muxrpc/v2/typemux"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
)

/*

  isFollowing: 'async',
  isBlocking: 'async',
  hops: 'source',
  blocks: 'source',

*/

var (
	_      ssb.Plugin = plugin{} // compile-time type check
	method            = muxrpc.Method{"friends"}
)

func checkAndLog(log logging.Interface, err error) {
	if err != nil {
		level.Error(log).Log("err", err)
	}
}

func New(log logging.Interface, self refs.FeedRef, b graph.Builder) ssb.Plugin {
	rootHdlr := typemux.New(log)

	rootHdlr.RegisterAsync(muxrpc.Method{"friends", "isFollowing"}, isFollowingH{
		log:     log,
		builder: b,
		self:    self,
	})

	rootHdlr.RegisterAsync(muxrpc.Method{"friends", "isBlocking"}, isBlockingH{
		log:     log,
		builder: b,
		self:    self,
	})

	rootHdlr.RegisterSource(muxrpc.Method{"friends", "blocks"}, blocksSrc{
		log:     log,
		builder: b,
		self:    self,
	})

	rootHdlr.RegisterSource(muxrpc.Method{"friends", "hops"}, hopsSrc{
		log:     log,
		builder: b,
		self:    self,
	})

	rootHdlr.RegisterAsync(muxrpc.Method{"friends", "plotsvg"}, plotSVGHandler{
		log:     log,
		builder: b,
		self:    self,
	})

	return plugin{
		h:   &rootHdlr,
		log: log,
	}
}

type plugin struct {
	h   muxrpc.Handler
	log logging.Interface
}

func (plugin) Name() string { return "friends" }

func (plugin) Method() muxrpc.Method {
	return method
}

func (p plugin) Handler() muxrpc.Handler {
	return p.h
}
