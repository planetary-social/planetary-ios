// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package friends

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb/graph"
	"go.mindeco.de/log"
	refs "go.mindeco.de/ssb-refs"
)

type sourceDestArg struct {
	Source refs.FeedRef `json:"source"`
	Dest   refs.FeedRef `json:"dest"`
}

type isFollowingH struct {
	self refs.FeedRef

	log log.Logger

	builder graph.Builder
}

func (h isFollowingH) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []sourceDestArg
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return nil, fmt.Errorf("invalid argument on isFollowing call: %w", err)
	}

	if len(args) != 1 {
		return nil, fmt.Errorf("expected one arg {source, dest}")
	}
	a := args[0]

	g, err := h.builder.Build()
	if err != nil {
		return nil, err
	}

	return g.Follows(a.Source, a.Dest), nil
}

type isBlockingH struct {
	self refs.FeedRef

	log log.Logger

	builder graph.Builder
}

func (h isBlockingH) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []sourceDestArg
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return nil, fmt.Errorf("invalid argument on isBlocking call: %w", err)
	}
	if len(args) != 1 {
		return nil, fmt.Errorf("expected one arg {source, dest}")
	}
	a := args[0]

	g, err := h.builder.Build()
	if err != nil {
		return nil, err
	}

	return g.Blocks(a.Source, a.Dest), nil
}

type plotSVGHandler struct {
	self refs.FeedRef

	log log.Logger

	builder graph.Builder
}

func (h plotSVGHandler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	g, err := h.builder.Build()
	if err != nil {
		return nil, err
	}

	fname, err := ioutil.TempFile("", "graph-*.svg")
	if err != nil {
		return nil, err
	}

	err = g.RenderSVG(fname)
	if err != nil {
		fname.Close()
		os.Remove(fname.Name())
		return nil, err
	}

	return fname.Name(), fname.Close()
}
