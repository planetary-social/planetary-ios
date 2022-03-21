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
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/ssb"
)

type wantHandler struct {
	wm  ssb.WantManager
	log logging.Interface
}

func (wantHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h wantHandler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	//h.log.Log("event", "onCall", "handler", "want", "args", fmt.Sprintf("%v", req.Args), "method", req.Method)
	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "async"
	}

	var wants []refs.BlobRef
	err := json.Unmarshal(req.RawArgs, &wants)
	if err != nil {
		err = fmt.Errorf("error parsing blob reference: %w", err)
		return nil, err
	}

	if len(wants) < 1 {
		// TODO: change from generic handlers to typed once (source, sink, async..)
		// async then would have to return a value or an error and not fall into this trap of not closing a stream
		return nil, fmt.Errorf("bad request - no args %d", len(wants))
	}
	for _, want := range wants {
		err = h.wm.Want(want)
		if err != nil {
			err = fmt.Errorf("error wanting blob reference: %w", err)
			return nil, err
		}
	}

	return true, nil
}
