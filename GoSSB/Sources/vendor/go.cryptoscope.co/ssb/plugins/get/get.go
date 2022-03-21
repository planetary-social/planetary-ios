// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package get is just a muxrpc wrapper around sbot.Get
package get

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/private"
	refs "go.mindeco.de/ssb-refs"
)

type plugin struct {
	h muxrpc.Handler
}

func (p plugin) Name() string            { return "get" }
func (p plugin) Method() muxrpc.Method   { return muxrpc.Method{"get"} }
func (p plugin) Handler() muxrpc.Handler { return p.h }

func New(g ssb.Getter, rxlog margaret.Log, unboxer *private.Manager) ssb.Plugin {
	return plugin{
		h: handler{
			get:     g,
			rxlog:   rxlog,
			unboxer: unboxer,
		},
	}
}

type handler struct {
	get     ssb.Getter
	rxlog   margaret.Log
	unboxer *private.Manager
}

func (handler) Handled(m muxrpc.Method) bool { return m.String() == "get" }

func (h handler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

type Option struct {
	ID      refs.MessageRef `json:"id"`
	Private bool            `json:"private"`
}

func (h handler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	var args []json.RawMessage
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		req.CloseWithError(err)
		return
	}

	if n := len(args); n < 1 {
		req.CloseWithError(fmt.Errorf("invalid argument count. Wanted 1 got %d", n))
		return
	}

	var o Option
	optErr := json.Unmarshal(args[0], &o)
	if optErr != nil {

		var asString refs.MessageRef
		strErr := json.Unmarshal(args[0], &asString)
		if strErr != nil {
			req.CloseWithError(fmt.Errorf("failed to parse argument as object (%s) and as string(%s)", optErr, strErr))
			return
		}

		o.ID = asString
	}

	msg, err := h.get.Get(o.ID)
	if err != nil {
		req.CloseWithError(fmt.Errorf("failed to load message: %w", err))
		return
	}
	var kv refs.KeyValueRaw
	kv.Key_ = msg.Key()
	kv.Value = *msg.ValueContent()

	if o.Private {
		cleartext, err := h.unboxer.DecryptMessage(msg)
		if err == nil {
			kv.Value.Meta = make(map[string]interface{}, 1)
			kv.Value.Meta["private"] = true

			kv.Value.Content = cleartext
		} else if err != private.ErrNotBoxed {
			req.CloseWithError(fmt.Errorf("failed to decrypt message: %w", err))
			return
		}
	}

	err = req.Return(ctx, kv)
	if err != nil {
		log.Printf("get(%s): failed? to return message: %s", o.ID.String(), err)
	}
}
