// SPDX-License-Identifier: MIT

package gossip

import (
	"context"
	"fmt"
	"sync"

	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/metrics"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
)

type HMACSecret *[32]byte

type HopCount int

type Promisc bool

func New(
	ctx context.Context,
	log logging.Interface,
	id *ssb.FeedRef,
	rootLog margaret.Log,
	userFeeds multilog.MultiLog,
	wantList ssb.ReplicationLister,
	opts ...interface{},
) *plugin {
	h := &handler{
		Id:        id,
		RootLog:   rootLog,
		UserFeeds: userFeeds,
		WantList:  wantList,
		Info:      log,
		rootCtx:   ctx,

		activeLock:  &sync.Mutex{},
		activeFetch: make(map[string]struct{}),
	}

	for i, o := range opts {
		switch v := o.(type) {
		case metrics.Gauge:
			h.sysGauge = v
		case metrics.Counter:
			h.sysCtr = v
		case HopCount:
			h.hopCount = int(v)
		case HMACSecret:
			h.hmacSec = v
		case Promisc:
			h.promisc = bool(v)
		default:
			log.Log("warning", "unhandled option", "i", i, "type", fmt.Sprintf("%T", o))
		}
	}
	if h.hopCount == 0 {
		h.hopCount = 1
	}

	h.feedManager = NewFeedManager(
		h.rootCtx,
		h.RootLog,
		h.UserFeeds,
		h.Info,
		h.sysGauge,
		h.sysCtr,
	)

	return &plugin{h}
}

func NewHist(
	ctx context.Context,
	log logging.Interface,
	id *ssb.FeedRef,
	rootLog margaret.Log,
	userFeeds multilog.MultiLog,
	wantList ssb.ReplicationLister,
	opts ...interface{},
) histPlugin {
	h := &handler{
		Id:        id,
		RootLog:   rootLog,
		UserFeeds: userFeeds,
		WantList:  wantList,
		Info:      log,
		rootCtx:   ctx,

		// not using fetch here
		activeLock:  nil,
		activeFetch: nil,
	}

	for i, o := range opts {
		switch v := o.(type) {
		case metrics.Gauge:
			h.sysGauge = v
		case metrics.Counter:
			h.sysCtr = v
		case Promisc:
			h.promisc = bool(v)
		case HopCount:
			h.hopCount = int(v)
		case HMACSecret:
			h.hmacSec = v
		default:
			log.Log("warning", "unhandled hist option", "i", i, "type", fmt.Sprintf("%T", o))
		}
	}

	if h.hopCount == 0 {
		h.hopCount = 1
	}

	h.feedManager = NewFeedManager(
		h.rootCtx,
		h.RootLog,
		h.UserFeeds,
		h.Info,
		h.sysGauge,
		h.sysCtr,
	)

	return histPlugin{h}
}

type plugin struct {
	h *handler
}

func (plugin) Name() string { return "gossip" }

func (plugin) Method() muxrpc.Method {
	return muxrpc.Method{"gossip"}
}

func (p plugin) Handler() muxrpc.Handler {
	return p.h
}

type histPlugin struct {
	h *handler
}

func (hp histPlugin) Name() string { return "createHistoryStream" }

func (histPlugin) Method() muxrpc.Method {
	return muxrpc.Method{"createHistoryStream"}
}

type IgnoreConnectHandler struct{ muxrpc.Handler }

func (IgnoreConnectHandler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}

func (hp histPlugin) Handler() muxrpc.Handler {
	return IgnoreConnectHandler{hp.h}
}
