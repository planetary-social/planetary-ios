// SPDX-License-Identifier: MIT

package blobs

import (
	"context"

	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb"
)

/*
blobs manifest.json except:
"get": "source",
"add": "sink",
"rm": "async",
"ls": "source",
"has": "async",
"want": "async",
"createWants": "source"

"size": "async",
"getSlice": "source",
"meta": "async",
"push": "async",
"changes": "source",
*/

var (
	_      ssb.Plugin = plugin{} // compile-time type check
	method            = muxrpc.Method{"blobs"}
)

func checkAndLog(log logging.Interface, err error) {
	if err != nil {
		level.Error(log).Log("err", err)
	}
}

func New(log logging.Interface, self ssb.FeedRef, bs ssb.BlobStore, wm ssb.WantManager) ssb.Plugin {
	rootHdlr := muxrpc.HandlerMux{}

	// TODO: needs priv checks
	// rootHdlr.Register(muxrpc.Method{"blobs", "add"}, addHandler{
	// 	log: log,
	// 	bs:  bs,
	// })
	// rootHdlr.Register(muxrpc.Method{"blobs", "list"}, listHandler{
	// 	log: log,
	// 	bs:  bs,
	// })
	// rootHdlr.Register(muxrpc.Method{"blobs", "rm"}, rmHandler{
	// 	log: log,
	// 	bs:  bs,
	// })

	var hs = []muxrpc.NamedHandler{
		{muxrpc.Method{"blobs", "get"}, getHandler{
			log: log,
			bs:  bs,
		}},
		{muxrpc.Method{"blobs", "has"}, hasHandler{
			log: log,
			bs:  bs,
		}},
		{muxrpc.Method{"blobs", "want"}, wantHandler{
			log: log,
			wm:  wm,
		}},
		{muxrpc.Method{"blobs", "createWants"}, &createWantsHandler{
			log:     log,
			self:    self,
			bs:      bs,
			wm:      wm,
			sources: make(map[string]luigi.Source),
		}},
	}
	rootHdlr.RegisterAll(hs...)

	return plugin{
		h:   &rootHdlr,
		log: log,
	}
}

type plugin struct {
	h   muxrpc.Handler
	log logging.Interface
}

func (plugin) Name() string { return "blobs" }

func (plugin) Method() muxrpc.Method {
	return method
}

func (p plugin) Handler() muxrpc.Handler {
	return p.h
}

func (plugin) WrapEndpoint(edp muxrpc.Endpoint) interface{} {
	return endpoint{edp}
}

type endpoint struct {
	edp muxrpc.Endpoint
}

func (edp endpoint) Add(ctx context.Context) (ssb.MessageRef, error) {
	return ssb.MessageRef{}, errors.New("not implemented yet")
}
