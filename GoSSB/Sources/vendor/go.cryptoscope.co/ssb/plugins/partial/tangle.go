// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package partial

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/mutil"
	"go.cryptoscope.co/ssb/internal/storedrefs"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog/roaring"
	"go.cryptoscope.co/muxrpc/v2"
	refs "go.mindeco.de/ssb-refs"
)

type getTangleHandler struct {
	rxlog margaret.Log

	get   ssb.Getter
	roots *roaring.MultiLog
}

func (h getTangleHandler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var mrs []refs.MessageRef
	err := json.Unmarshal(req.RawArgs, &mrs)
	if err != nil {
		return nil, err
	}

	if len(mrs) != 1 {
		return nil, fmt.Errorf("no args")
	}
	msg, err := h.get.Get(mrs[0])
	if err != nil {
		return nil, fmt.Errorf("getTangle: root message not found: %w", err)
	}

	vals := []interface{}{
		msg.ValueContentJSON(),
	}

	threadLog, err := h.roots.Get(storedrefs.Message(msg.Key()))
	if err != nil {
		return nil, fmt.Errorf("getTangle: failed to load thread: %w", err)
	}

	src, err := mutil.Indirect(h.rxlog, threadLog).Query()
	if err != nil {
		return nil, fmt.Errorf("getTangle: failed to qry tipe: %w", err)
	}

	snk := luigi.NewSliceSink(&vals)
	err = luigi.Pump(ctx, snk, src)
	if err != nil {
		return nil, fmt.Errorf("getTangle: failed to pump msgs: %w", err)
	}
	return nil, fmt.Errorf("partial: TODO refactor")
	return vals, nil
}
