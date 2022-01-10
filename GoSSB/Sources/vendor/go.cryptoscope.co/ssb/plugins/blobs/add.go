// SPDX-License-Identifier: MIT

package blobs

import (
	"context"

	"github.com/cryptix/go/logging"
	"github.com/pkg/errors"

	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb"
)

type addHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (addHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h addHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "sink"
	}

	r := muxrpc.NewSourceReader(req.Stream)
	ref, err := h.bs.Put(r)
	checkAndLog(h.log, errors.Wrap(err, "error putting blob"))

	req.Return(ctx, ref)
}
