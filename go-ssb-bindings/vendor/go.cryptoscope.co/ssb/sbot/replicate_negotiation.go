package sbot

import (
	"context"
	"time"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/plugins/ebt"
	"go.cryptoscope.co/ssb/plugins/gossip"
)

type replicateNegotiator struct {
	logger log.Logger

	lg *gossip.LegacyGossip

	ebt *ebt.MUXRPCHandler

	// these control outgoing replication behaviour
	disableEBT        bool
	disableLiveLegacy bool
}

func (rn replicateNegotiator) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {
	if rn.disableEBT {
		rn.lg.StartLegacyFetching(ctx, e, !rn.disableLiveLegacy)
		return
	}

	remoteAddr := e.Remote()

	// the client calls ebt.replicate to the server
	if !muxrpc.IsServer(e) {
		// do nothing if we are the server, unless the peer doesn't start ebt
		started := rn.ebt.Sessions.WaitFor(ctx, remoteAddr, 1*time.Minute)
		if !started {
			rn.lg.StartLegacyFetching(ctx, e, !rn.disableLiveLegacy)
		}
		return
	}

	remote, err := ssb.GetFeedRefFromAddr(remoteAddr)
	if err != nil {
		panic(err)
		return
	}

	level.Debug(rn.logger).Log("event", "triggering ebt.replicate", "r", remote.ShortRef())

	var opt = map[string]interface{}{"version": 3}

	// initiate ebt channel
	rx, tx, err := e.Duplex(ctx, muxrpc.TypeJSON, muxrpc.Method{"ebt", "replicate"}, opt)
	if err != nil {
		level.Debug(rn.logger).Log("event", "no ebt support", "err", err)

		// fallback to legacy
		rn.lg.StartLegacyFetching(ctx, e, !rn.disableLiveLegacy)
		return
	}

	rn.ebt.Loop(ctx, tx, rx, remoteAddr)
}

func (replicateNegotiator) Handled(m muxrpc.Method) bool { return false }

func (rn replicateNegotiator) HandleCall(ctx context.Context, req *muxrpc.Request) {
	// noop - this handler only controls outgoing calls for replication
}

type negPlugin struct{ replicateNegotiator }

func (p negPlugin) Name() string            { return "negotiate" }
func (p negPlugin) Method() muxrpc.Method   { return muxrpc.Method{"negotiate"} }
func (p negPlugin) Handler() muxrpc.Handler { return p.replicateNegotiator }
