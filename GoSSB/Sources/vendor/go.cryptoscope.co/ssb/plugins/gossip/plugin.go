// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package gossip

import (
	"context"
	"fmt"

	"github.com/go-kit/kit/metrics"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/repo"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"
	refs "go.mindeco.de/ssb-refs"
)

// todo: make these proper functional options

type HMACSecret *[32]byte

type Promisc bool

type WithLive bool

// NewFetcher returns a muxrpc handler plugin which requests and verifies feeds, based on the passed replication lister.
func NewFetcher(
	ctx context.Context,
	log logging.Interface,
	r repo.Interface,
	id refs.FeedRef,
	rxlog margaret.Log,
	userFeeds multilog.MultiLog,
	fm *FeedManager,
	wantList ssb.ReplicationLister,
	vr *message.VerificationRouter,
	opts ...interface{},
) *plugin {
	h := &LegacyGossip{
		repo: r,

		ReceiveLog: rxlog,

		Id: id,

		UserFeeds:   userFeeds,
		feedManager: fm,
		WantList:    wantList,

		Info:    log,
		rootCtx: ctx,

		verifyRouter: vr,

		enableLiveStreaming: true,
	}

	for i, o := range opts {
		switch v := o.(type) {
		case metrics.Gauge:
			h.sysGauge = v
		case metrics.Counter:
			h.sysCtr = v
		case HMACSecret:
			h.hmacSec = v
		case Promisc:
			h.promisc = bool(v)
		case WithLive:
			h.enableLiveStreaming = bool(v)
		default:
			level.Warn(log).Log("event", "unhandled gossip option", "i", i, "type", fmt.Sprintf("%T", o))
		}
	}

	return &plugin{h}
}

// NewServer just handles the "supplying" side of gossip replication.
func NewServer(
	ctx context.Context,
	log logging.Interface,
	id refs.FeedRef,
	rxlog margaret.Log,
	userFeeds multilog.MultiLog,
	wantList ssb.ReplicationLister,
	fm *FeedManager,
	opts ...interface{},
) histPlugin {
	h := &LegacyGossip{
		Id: id,

		ReceiveLog:  rxlog,
		UserFeeds:   userFeeds,
		feedManager: fm,
		WantList:    wantList,

		Info:    log,
		rootCtx: ctx,
	}

	for i, o := range opts {
		switch v := o.(type) {
		case metrics.Gauge:
			h.sysGauge = v
		case metrics.Counter:
			h.sysCtr = v
		case Promisc:
			h.promisc = bool(v)
		case HMACSecret:
			h.hmacSec = v
		case WithLive:
			// no consequence - the outgoing live code is fine
		default:
			level.Warn(log).Log("event", "unhandled gossip option", "i", i, "type", fmt.Sprintf("%T", o))
		}
	}

	return histPlugin{h}
}

type plugin struct {
	*LegacyGossip
}

func (plugin) Name() string { return "gossip" }

func (plugin) Method() muxrpc.Method {
	return muxrpc.Method{"gossip"}
}

func (p plugin) Handler() muxrpc.Handler {
	return p.LegacyGossip
}

type histPlugin struct {
	*LegacyGossip
}

func (hp histPlugin) Name() string { return "createHistoryStream" }

func (histPlugin) Method() muxrpc.Method {
	return muxrpc.Method{"createHistoryStream"}
}

type IgnoreConnectHandler struct{ muxrpc.Handler }

func (IgnoreConnectHandler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}

func (hp histPlugin) Handler() muxrpc.Handler {
	return IgnoreConnectHandler{hp.LegacyGossip}
}
