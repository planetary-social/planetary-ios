// SPDX-License-Identifier: MIT

package replicate

import (
	"context"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
)

type replicatePlug struct {
	h muxrpc.Handler
}

// TODO: add replicate, block, changes
func NewPlug(users multilog.MultiLog) ssb.Plugin {
	plug := &replicatePlug{}
	plug.h = replicateHandler{
		users: users,
	}
	return plug
}

func (lt replicatePlug) Name() string { return "replicate" }

func (replicatePlug) Method() muxrpc.Method {
	return muxrpc.Method{"replicate"}
}
func (lt replicatePlug) Handler() muxrpc.Handler {
	return lt.h
}

type replicateHandler struct {
	users multilog.MultiLog
}

func (g replicateHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (g replicateHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	if len(req.Method) < 2 && req.Method[1] != "upto" {
		req.CloseWithError(errors.Errorf("invalid method"))
		return
	}

	storedFeeds, err := g.users.List()
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "replicate: did not get user list"))
		return
	}

	for i, author := range storedFeeds {
		var sr ssb.StorageRef
		err := sr.Unmarshal([]byte(author))
		if err != nil {
			req.CloseWithError(errors.Wrapf(err, "replicate(%d): invalid storage ref", i))
			return
		}
		authorRef, err := sr.FeedRef()
		if err != nil {
			req.CloseWithError(errors.Wrapf(err, "replicate(%d): stored ref not a feed?", i))
			return
		}

		subLog, err := g.users.Get(author)
		if err != nil {
			req.CloseWithError(errors.Wrapf(err, "replicate(%d): did not load sublog", i))
			return
		}

		currSeq, err := subLog.Seq().Value()
		if err != nil {
			req.CloseWithError(errors.Wrapf(err, "replicate(%d): failed to get current seq value", i))
			return
		}

		err = req.Stream.Pour(ctx, UpToResponse{
			ID:       authorRef,
			Sequence: currSeq.(margaret.Seq).Seq() + 1})
		if err != nil {
			req.CloseWithError(errors.Wrapf(err, "replicate(%d): failed to pump msgs", i))
			return
		}

	}

	req.Stream.Close()
}

type UpToResponse struct {
	ID       *ssb.FeedRef `json:"id"`
	Sequence int64        `json:"sequence"`
}
