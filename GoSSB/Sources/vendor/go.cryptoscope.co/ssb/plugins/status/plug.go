// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package status

import (
	"context"
	"log"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb"
)

type Plugin struct {
	status ssb.Statuser
}

func New(st ssb.Statuser) *Plugin {
	return &Plugin{
		status: st,
	}
}

func (lt Plugin) Name() string            { return "status" }
func (Plugin) Method() muxrpc.Method      { return muxrpc.Method{"status"} }
func (lt Plugin) Handler() muxrpc.Handler { return lt }

func (Plugin) Handled(m muxrpc.Method) bool { return m.String() == "status" }

func (g Plugin) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (g Plugin) HandleCall(ctx context.Context, req *muxrpc.Request) {
	s, err := g.status.Status()
	if err != nil {
		log.Println("statusErr", err)
		req.CloseWithError(err)
		return
	}

	err = req.Return(ctx, s)
	if err != nil {
		log.Println("statusErr", err)
		req.CloseWithError(err)
		return
	}
}
