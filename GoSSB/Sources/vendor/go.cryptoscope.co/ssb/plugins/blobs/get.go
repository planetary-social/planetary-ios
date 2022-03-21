// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb/blobstore"
	"go.mindeco.de/log"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

type getHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (getHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h getHandler) HandleSource(ctx context.Context, req *muxrpc.Request, snk *muxrpc.ByteSink) error {
	logger := log.With(h.log, "handler", "get")
	// errLog := level.Error(logger)

	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "source"
	}

	var wantedRef refs.BlobRef
	var maxSize uint = blobstore.DefaultMaxSize

	var justTheRef []refs.BlobRef
	if err := json.Unmarshal(req.RawArgs, &justTheRef); err != nil {
		var withSize []blobstore.GetWithSize
		if err := json.Unmarshal(req.RawArgs, &withSize); err != nil {
			return fmt.Errorf("bad request - invalid json: %w", err)
		}
		if len(withSize) != 1 {
			return errors.New("bad request")
		}
		wantedRef = withSize[0].Key
		maxSize = withSize[0].Max
	} else {
		if len(justTheRef) != 1 {
			return errors.New("bad request")
		}
		wantedRef = justTheRef[0]
	}

	sz, err := h.bs.Size(wantedRef)
	if err != nil {
		return errors.New("do not have blob")
	}

	if sz > 0 && uint(sz) > maxSize {
		return errors.New("blob larger than you wanted")
	}

	logger = log.With(logger, "blob", wantedRef.ShortSigil())

	r, err := h.bs.Get(wantedRef)
	if err != nil {
		return errors.New("do not have blob")
	}

	w := muxrpc.NewSinkWriter(snk)

	_, err = io.Copy(w, r)
	if err != nil {
		return fmt.Errorf("error sending blob: %w", err)
	}

	err = w.Close()
	if err != nil {
		return fmt.Errorf("error closing blob output: %w", err)
	}
	// if err == nil {
	// 	info.Log("event", "transmission successfull", "took", time.Since(start))
	// }
	return nil
}
