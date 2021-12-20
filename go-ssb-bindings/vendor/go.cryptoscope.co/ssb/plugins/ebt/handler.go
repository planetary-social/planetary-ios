// SPDX-License-Identifier: MIT

package ebt

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"

	"go.mindeco.de/log"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/statematrix"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/plugins/gossip"
	refs "go.mindeco.de/ssb-refs"
)

type MUXRPCHandler struct {
	info logging.Interface

	self      refs.FeedRef
	rootLog   margaret.Log
	userFeeds multilog.MultiLog

	livefeeds *gossip.FeedManager

	// wantList ssb.ReplicationLister

	stateMatrix *statematrix.StateMatrix

	verify *message.VerificationRouter

	Sessions Sessions
}

func (h *MUXRPCHandler) check(err error) {
	if err != nil && !muxrpc.IsSinkClosed(err) {
		level.Error(h.info).Log("error", err)
	}
}

func (MUXRPCHandler) Handled(m muxrpc.Method) bool { return m.String() == "ebt.replicate" }

// HandleConnect does nothing. Feature negotiation is done by sbot
func (h *MUXRPCHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

// HandleCall handles the server side (getting called by client)
func (h *MUXRPCHandler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	checkAndClose := func(err error) {
		h.check(err)
		if err != nil {
			closeErr := req.CloseWithError(err)
			h.check(fmt.Errorf("error closeing request %q: %w", req.Method, closeErr))
		}
	}

	if req.Type != "duplex" {
		checkAndClose(fmt.Errorf("invalid type: %s", req.Type))
		return
	}

	var args []struct{ Version int }
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		checkAndClose(err)
		return
	}

	if n := len(args); n != 1 {
		checkAndClose(fmt.Errorf("expected one argument but got %d", n))
		return
	}

	if args[0].Version != 3 {
		checkAndClose(errors.New("go-ssb only support ebt v3"))
		return
	}
	level.Debug(h.info).Log("event", "replicating", "version", args[0].Version)

	// get writer and reader from duplex call
	snk, err := req.ResponseSink()
	if err != nil {
		checkAndClose(err)
		return
	}

	src, err := req.ResponseSource()
	if err != nil {
		checkAndClose(err)
		return
	}

	h.Loop(ctx, snk, src, req.RemoteAddr())
}

func (h *MUXRPCHandler) sendState(ctx context.Context, tx *muxrpc.ByteSink, remote refs.FeedRef) error {
	currState, err := h.stateMatrix.Changed(h.self, remote)
	if err != nil {
		return fmt.Errorf("failed to get changed frontier: %w", err)
	}

	selfRef := h.self.Ref()

	// don't receive your own feed
	if myNote, has := currState[selfRef]; has {
		myNote.Receive = false
		currState[selfRef] = myNote
	}

	tx.SetEncoding(muxrpc.TypeJSON)
	err = json.NewEncoder(tx).Encode(currState)
	if err != nil {
		return fmt.Errorf("failed to send currState: %d: %w", len(currState), err)
	}

	return nil
}

// Loop executes the ebt logic loop, reading from the peer and sending state and messages as requests
func (h *MUXRPCHandler) Loop(ctx context.Context, tx *muxrpc.ByteSink, rx *muxrpc.ByteSource, remoteAddr net.Addr) {
	session := h.Sessions.Started(remoteAddr)

	peer, err := ssb.GetFeedRefFromAddr(remoteAddr)
	if err != nil {
		h.check(err)
		return
	}

	peerLogger := log.With(h.info, "r", peer.ShortRef())

	defer func() {
		h.Sessions.Ended(remoteAddr)

		level.Debug(peerLogger).Log("event", "loop exited")
		err := h.stateMatrix.SaveAndClose(peer)
		if err != nil {
			level.Warn(h.info).Log("event", "failed to save state matrix for peer", "err", err)
		}
	}()

	if err := h.sendState(ctx, tx, peer); err != nil {
		h.check(err)
		return
	}

	var buf = &bytes.Buffer{}
	for rx.Next(ctx) { // read/write loop for messages

		buf.Reset()
		err := rx.Reader(func(r io.Reader) error {
			_, err := buf.ReadFrom(r)
			return err
		})
		if err != nil {
			h.check(err)
			return
		}

		jsonBody := buf.Bytes()

		var frontierUpdate ssb.NetworkFrontier
		err = json.Unmarshal(jsonBody, &frontierUpdate)
		if err != nil { // assume it's a message

			// redundant pass of finding out the author
			// would be rad to get this from the pretty-printed version
			// and just pass that to verify
			var msgWithAuthor struct {
				Author refs.FeedRef
			}

			err := json.Unmarshal(jsonBody, &msgWithAuthor)
			if err != nil {
				h.check(err)
				continue
			}

			vsnk, err := h.verify.GetSink(msgWithAuthor.Author, true)
			if err != nil {
				h.check(err)
				continue
			}

			err = vsnk.Verify(jsonBody)
			if err != nil {
				// TODO: mark feed as bad
				h.check(err)
			}

			continue
		}

		// update our network perception
		wants, err := h.stateMatrix.Update(peer, frontierUpdate)
		if err != nil {
			h.check(err)
			return
		}

		// TODO: partition wants across the open connections
		// one peer might be closer to a feed
		// for this we also need timing and other heuristics

		// ad-hoc send where we have newer messages
		for feedStr, their := range wants {
			// these were already validated by the .UnmarshalJSON() method
			// but we need the refs.Feed for the createHistArgs
			feed, err := refs.ParseFeedRef(feedStr)
			if err != nil {
				h.check(err)
				return
			}

			if !their.Replicate {
				continue
			}

			if !their.Receive {
				session.Unubscribe(feed)
				continue
			}

			arg := message.CreateHistArgs{
				ID:  feed,
				Seq: int64(their.Seq + 1),
			}
			arg.Limit = -1
			arg.Live = true

			// TODO: it might not scale to do this with contexts (each one has a goroutine)
			// in that case we need to rework the internal/luigiutils MultiSink so that we can unsubscribe on it directly
			ctx, cancel := context.WithCancel(ctx)

			err = h.livefeeds.CreateStreamHistory(ctx, tx, arg)
			if err != nil {
				cancel()
				h.check(err)
				return
			}
			session.Subscribed(feed, cancel)
		}
	}

	h.check(rx.Err())
}
