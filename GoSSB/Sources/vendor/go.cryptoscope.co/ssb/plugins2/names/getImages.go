// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package names

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"
	refs "go.mindeco.de/ssb-refs"
)

type hImagesFor struct {
	as  aboutStore
	log logging.Interface
}

func (h hImagesFor) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {

	ref, err := parseFeedRefFromArgs(req)
	if err != nil {
		return nil, err
	}

	ai, err := h.as.CollectedFor(ref)
	if err != nil {
		return nil, fmt.Errorf("do not have about for: %s", ref.String())
	}

	if ai.Image.Chosen != "" {
		return ai.Image.Chosen, nil
	}

	// this is suboptimal, just got started but didnt finish
	// ideal would take into account who your friends are, not everyone you see
	var mostSet string
	var most = 0
	for v, cnt := range ai.Image.Prescribed {
		if most > cnt {
			most = cnt
			mostSet = v
		}
	}

	return mostSet, nil
}

func parseFeedRefFromArgs(req *muxrpc.Request) (refs.FeedRef, error) {

	var args []refs.FeedRef
	err := json.Unmarshal(req.RawArgs, &args)
	if err == nil && len(args) == 1 {
		return args[0], nil
	}

	var objArgs []struct {
		ID refs.FeedRef `json:"id"`
	}
	err = json.Unmarshal(req.RawArgs, &objArgs)
	if err == nil && len(args) == 1 {
		return objArgs[0].ID, nil
	}

	return refs.FeedRef{}, fmt.Errorf("error parsing arguments: %v", err)
}
