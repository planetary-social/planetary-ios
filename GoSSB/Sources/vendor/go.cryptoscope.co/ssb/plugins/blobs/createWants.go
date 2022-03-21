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
	"sync"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
	refs "go.mindeco.de/ssb-refs"
)

type createWantsHandler struct {
	log logging.Interface

	self refs.FeedRef

	bs ssb.BlobStore
	wm ssb.WantManager

	// sources is a map if sources where the responses are read from.
	sources map[string]*muxrpc.ByteSource

	// l protects sources.
	l sync.Mutex
}

// getSource looks if we have a source for that remote and, if not, make a
// source call to get one.
func (h *createWantsHandler) getSource(ctx context.Context, edp muxrpc.Endpoint) (*muxrpc.ByteSource, error) {
	ref := edp.Remote().String()

	h.l.Lock()
	defer h.l.Unlock()

	src, ok := h.sources[ref]
	if ok {
		if src != nil {
			return src, nil
		}
		level.Debug(h.log).Log("msg", "got a nil source from the map, ignoring and making new")
	}

	bSrc, err := edp.Source(ctx, muxrpc.TypeJSON, muxrpc.Method{"blobs", "createWants"})
	if err != nil {
		return nil, fmt.Errorf("error making source call: %w", err)
	}
	if bSrc == nil {
		return nil, errors.New("failed to get createWants source from remote")
	}
	h.sources[ref] = bSrc
	return bSrc, nil
}

func (h *createWantsHandler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
	ref, err := ssb.GetFeedRefFromAddr(edp.Remote())
	if err != nil {
		return
	}
	if ref.Equal(h.self) {
		return
	}

	_, err = h.getSource(ctx, edp)
	if err != nil && !muxrpc.IsSinkClosed(err) {
		level.Warn(h.log).Log("method", "blobs.createWants", "handler", "onConnect", "getSourceErr", err)
		return
	}
}

func (h *createWantsHandler) HandleSource(ctx context.Context, req *muxrpc.Request, snk *muxrpc.ByteSink) error {
	edp := req.Endpoint()

	src, err := h.getSource(ctx, edp)
	if err != nil {
		return fmt.Errorf("failed to get source: %w", err)
	}

	updates := h.wm.CreateWants(ctx, snk, edp)
	if updates == nil {
		return fmt.Errorf("failed to get source: %w", err)
	}

	for src.Next(ctx) {
		err = src.Reader(func(r io.Reader) error {
			var wantMsg blobstore.WantMsg
			err := json.NewDecoder(r).Decode(&wantMsg)
			if err != nil {
				return err
			}
			return updates.Pour(ctx, wantMsg)
		})
		if err != nil {
			level.Warn(h.log).Log("event", "onCall", "handler", "createWants", "pipe-err", err)
			break
		}

	}

	if err == nil {
		err = src.Err()
	}

	if err != nil && !muxrpc.IsSinkClosed(err) && !errors.Is(err, context.Canceled) {
		level.Debug(h.log).Log("event", "onCall", "handler", "createWants", "err", err)
	}

	h.l.Lock()
	defer h.l.Unlock()
	delete(h.sources, edp.Remote().String())

	snk.Close()
	return nil
}
