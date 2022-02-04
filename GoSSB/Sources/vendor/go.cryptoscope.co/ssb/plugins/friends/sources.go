// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package friends

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb/graph"
	"go.mindeco.de/log"
	refs "go.mindeco.de/ssb-refs"
)

type blocksSrc struct {
	self refs.FeedRef

	log log.Logger

	builder graph.Builder
}

func (h blocksSrc) HandleSource(ctx context.Context, req *muxrpc.Request, snk *muxrpc.ByteSink) error {
	type argT struct {
		Who refs.FeedRef
	}
	var args []argT
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return fmt.Errorf("invalid argument on isFollowing call: %w", err)
	}

	var who refs.FeedRef
	if len(args) != 1 {
		who = h.self
	} else {
		who = args[0].Who
	}

	g, err := h.builder.Build()
	if err != nil {
		return err
	}

	set := g.BlockedList(who)
	lst, err := set.List()
	if err != nil {
		return err
	}

	snk.SetEncoding(muxrpc.TypeJSON)
	enc := json.NewEncoder(snk)

	for i, v := range lst {
		if err := enc.Encode(v); err != nil {
			return fmt.Errorf("blocks: failed to send item %d: %w", i, err)
		}
	}

	return snk.Close()
}

type hopsSrc struct {
	self refs.FeedRef

	log log.Logger

	builder graph.Builder
}

type HopsArgs struct {
	Start *refs.FeedRef `json:"start,omitempty"`
	Max   uint          `json:"max"`
}

func (h hopsSrc) HandleSource(ctx context.Context, req *muxrpc.Request, snk *muxrpc.ByteSink) error {
	var args []HopsArgs
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return fmt.Errorf("invalid argument on isFollowing call: %w", err)
	}

	var (
		start refs.FeedRef
		dist  uint
	)
	if len(args) == 1 {
		if s := args[0].Start; s != nil {
			start = *s
		} else {
			start = h.self
		}
		dist = args[0].Max
	}

	set := h.builder.Hops(start, int(dist))

	lst, err := set.List()
	if err != nil {
		return err
	}

	snk.SetEncoding(muxrpc.TypeJSON)
	enc := json.NewEncoder(snk)

	for i, v := range lst {
		if err := enc.Encode(v); err != nil {
			return fmt.Errorf("hops: failed to send item %d: %w", i, err)
		}
	}

	return snk.Close()
}
