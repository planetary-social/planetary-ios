// SPDX-License-Identifier: MIT

package publish

import (
	"github.com/cryptix/go/logging"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
)

type publishPlug struct {
	h muxrpc.Handler
}

func NewPlug(i logging.Interface, publish ssb.Publisher, rootLog margaret.Log) ssb.Plugin {
	return &publishPlug{h: handler{
		publish: publish,
		rootLog: rootLog,
		info:    i,
	}}
}

func (p publishPlug) Name() string {
	return "publish"
}

func (p publishPlug) Method() muxrpc.Method {
	return muxrpc.Method{"publish"}
}

func (p publishPlug) Handler() muxrpc.Handler {
	return p.h
}
