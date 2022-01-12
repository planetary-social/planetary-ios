// SPDX-License-Identifier: MIT

package friends

import (
	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/log/level"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/internal/muxmux"
)

/*

  isFollowing: 'async',
  isBlocking: 'async',
  hops: 'async',

extra:

  follows: 'source',
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

func New(log logging.Interface, self ssb.FeedRef, b graph.Builder) ssb.Plugin {
	rootHdlr := muxmux.New(log)

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

// not sure what this was about
func (plugin) WrapEndpoint(edp muxrpc.Endpoint) interface{} {
	return endpoint{edp}
}

type endpoint struct {
	edp muxrpc.Endpoint
}

/*
func (edp endpoint) Add(ctx context.Context) (ssb.MessageRef, error) {
	return ssb.MessageRef{}, errors.New("not implemented yet")
}
*/
