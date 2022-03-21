// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package blobs implements the muxrpc handlers for npm:ssb-blobs.
// The storage and want-managment is found in the blobstore package.
package blobs

import (
	"context"
	"errors"

	"go.cryptoscope.co/muxrpc/v2/typemux"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
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

func New(log logging.Interface, self refs.FeedRef, bs ssb.BlobStore, wm ssb.WantManager) ssb.Plugin {
	mux := typemux.New(log)

	mux.RegisterSink(muxrpc.Method{"blobs", "add"}, addHandler{
		self: self,
		log:  log,
		bs:   bs,
	})
	// mux.Register(muxrpc.Method{"blobs", "list"}, listHandler{
	// 	log: log,
	// 	bs:  bs,
	// })
	// mux.Register(muxrpc.Method{"blobs", "rm"}, rmHandler{
	// 	log: log,
	// 	bs:  bs,
	// })

	mux.RegisterSource(muxrpc.Method{"blobs", "get"}, getHandler{
		log: log,
		bs:  bs,
	})

	mux.RegisterAsync(muxrpc.Method{"blobs", "has"}, hasHandler{
		log: log,
		bs:  bs,
	})

	mux.RegisterAsync(muxrpc.Method{"blobs", "size"}, sizeHandler{
		log: log,
		bs:  bs,
	})

	mux.RegisterAsync(muxrpc.Method{"blobs", "want"}, wantHandler{
		log: log,
		wm:  wm,
	})

	mux.RegisterSource(muxrpc.Method{"blobs", "createWants"}, &createWantsHandler{
		log:     log,
		self:    self,
		bs:      bs,
		wm:      wm,
		sources: make(map[string]*muxrpc.ByteSource),
	})

	return plugin{
		h:   &mux,
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

func (edp endpoint) Add(ctx context.Context) (refs.MessageRef, error) {
	return refs.MessageRef{}, errors.New("not implemented yet")
}
