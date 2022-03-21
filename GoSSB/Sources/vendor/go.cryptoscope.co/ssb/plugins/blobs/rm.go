// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

type rmHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (rmHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h rmHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "async"
	}

	var refs []refs.BlobRef

	err := json.Unmarshal(req.RawArgs, &refs)
	if err != nil {
		checkAndLog(h.log, fmt.Errorf("error parsing blob reference: %w", err))
		return
	}
	if len(refs) != 1 {
		// TODO: change from generic handlers to typed once (source, sink, async..)
		// async then would have to return a value or an error and not fall into this trap of not closing a stream
		req.Stream.CloseWithError(errors.New("bad request - wrong args"))
		return
	}

	br := refs[0]

	err = h.bs.Delete(br)
	if err != nil {
		checkAndLog(h.log, fmt.Errorf("error deleting blob: %w", err))
		err = req.Stream.CloseWithError(errors.New("do not have blob"))
	}
}
