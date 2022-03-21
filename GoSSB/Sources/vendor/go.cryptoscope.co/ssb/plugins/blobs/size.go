// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobs

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

type sizeHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (sizeHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h sizeHandler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "async"
	}

	var blobs []refs.BlobRef
	err := json.Unmarshal(req.RawArgs, &blobs)
	if err != nil {
		return nil, fmt.Errorf("error parsing blob reference: %w", err)
	}

	if len(blobs) != 1 {
		return nil, fmt.Errorf("bad request - got %d arguments, expected 1", len(blobs))
	}

	sz, err := h.bs.Size(blobs[0])
	if err != nil {
		return nil, fmt.Errorf("error looking up blob: %w", err)
	}

	return sz, nil
}
