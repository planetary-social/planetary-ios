// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package names

import (
	"context"
	"os"

	"go.cryptoscope.co/muxrpc/v2/typemux"
	"go.mindeco.de/log"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"
)

type Plugin struct {
	about aboutStore
}

func (lt Plugin) Name() string            { return "names" }
func (Plugin) Method() muxrpc.Method      { return muxrpc.Method{"names"} }
func (lt Plugin) Handler() muxrpc.Handler { return newNamesHandler(nil, lt.about) }

func newNamesHandler(l log.Logger, as aboutStore) muxrpc.Handler {

	if l == nil {
		l = log.NewLogfmtLogger(os.Stderr)
		l = log.With(l, "plugin", "names")
	}

	mux := typemux.New(l)

	mux.RegisterAsync(muxrpc.Method{"names", "get"}, hGetAll{
		log: l,
		as:  as,
	})
	mux.RegisterAsync(muxrpc.Method{"names", "getImageFor"}, hImagesFor{
		log: l,
		as:  as,
	})
	mux.RegisterAsync(muxrpc.Method{"names", "getSignifier"}, hGetSignifier{
		log: l,
		as:  as,
	})

	return &mux
}

type hGetAll struct {
	as  aboutStore
	log logging.Interface
}

func (h hGetAll) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	return h.as.All()
}
