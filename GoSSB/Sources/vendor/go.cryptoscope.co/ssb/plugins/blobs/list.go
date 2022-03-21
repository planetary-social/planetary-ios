// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobs

import (
	"context"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
)

type listHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (listHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h listHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "source"
	}

	err := luigi.Pump(ctx, req.Stream, h.bs.List())
	if err != nil {
		err = fmt.Errorf("error listing blobs: %w", err)
		checkAndLog(h.log, err)
	}
}
