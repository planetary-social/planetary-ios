// SPDX-License-Identifier: MIT

package control

import (
	"github.com/cryptix/go/logging"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
)

type connectPlug struct {
	h muxrpc.Handler
}

func NewPlug(i logging.Interface, n ssb.Network) ssb.Plugin {
	return &connectPlug{h: New(i, n)}
}

func (p connectPlug) Name() string {
	return "control"
}

func (p connectPlug) Method() muxrpc.Method {
	return muxrpc.Method{"ctrl"}
}

func (p connectPlug) Handler() muxrpc.Handler {
	return p.h
}
