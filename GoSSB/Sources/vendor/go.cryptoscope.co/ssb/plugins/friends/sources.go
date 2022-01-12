package friends

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/go-kit/kit/log"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
)

type blocksSrc struct {
	self ssb.FeedRef

	log log.Logger

	builder graph.Builder
}

func (h blocksSrc) HandleSource(ctx context.Context, req *muxrpc.Request, snk luigi.Sink) error {
	type argT struct {
		Who ssb.FeedRef
	}
	var args []argT
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return fmt.Errorf("invalid argument on isFollowing call: %w", err)
	}

	var who ssb.FeedRef
	if len(args) != 1 {
		who = h.self
	} else {
		who = args[0].Who
	}

	g, err := h.builder.Build()
	if err != nil {
		return err
	}

	set := g.BlockedList(&who)
	lst, err := set.List()
	if err != nil {
		return err
	}
	for i, v := range lst {
		if err := snk.Pour(ctx, v); err != nil {
			return fmt.Errorf("blocks: failed to send item %d: %w", i, err)
		}
	}

	return snk.Close()
}

type hopsSrc struct {
	self ssb.FeedRef

	log log.Logger

	builder graph.Builder
}

type HopsArgs struct {
	Start *ssb.FeedRef `json:"start,omitempty"`
	Max   uint         `json:"max"`
}

func (h hopsSrc) HandleSource(ctx context.Context, req *muxrpc.Request, snk luigi.Sink) error {
	var args []HopsArgs
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return fmt.Errorf("invalid argument on isFollowing call: %w", err)
	}

	var (
		start *ssb.FeedRef
		dist  uint
	)
	if len(args) == 1 {
		start = args[0].Start
		dist = args[0].Max
	}

	if start == nil {
		start = &h.self
	}

	set := h.builder.Hops(start, int(dist))

	lst, err := set.List()
	if err != nil {
		return err
	}
	for i, v := range lst {
		if err := snk.Pour(ctx, v); err != nil {
			return fmt.Errorf("hops: failed to send item %d: %w", i, err)
		}
	}

	return snk.Close()
}
