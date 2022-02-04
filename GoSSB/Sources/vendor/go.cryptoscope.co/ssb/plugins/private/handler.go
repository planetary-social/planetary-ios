// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package private

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/transform"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/private"
	refs "go.mindeco.de/ssb-refs"
)

type handler struct {
	info logging.Interface

	author  refs.FeedRef
	publish ssb.Publisher
	read    margaret.Log

	mngr *private.Manager
}

func (h handler) handlePublish(ctx context.Context, req *muxrpc.Request) (interface{}, error) {

	// first arg is the message, 2nd is a slice of recipients
	var args []json.RawMessage
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return nil, fmt.Errorf("private/publish: failed to decode call arguments: %w", err)
	}

	if len(args) != 2 {
		return nil, fmt.Errorf("private/publish: expected [content, [recps,..]]: %w", err)
	}
	content := args[0]

	var recps []refs.AnyRef
	err = json.Unmarshal(args[1], &recps)
	if err != nil {
		return nil, fmt.Errorf("private/publish: failed to decode recipients: %w", err)
	}

	filtered := make([]refs.Ref, len(recps))
	var box2mode = false
	var i int
	for _, rv := range recps {
		if mr, yes := rv.IsMessage(); yes {
			box2mode = true
			filtered[i] = mr
			i++
		}

		if fr, yes := rv.IsFeed(); yes {
			filtered[i] = fr
			i++
		}
	}

	// cut of excess
	filtered = filtered[:i]

	var ctxt []byte
	if box2mode {
		ctxt, err = h.privatePublishBox2(content, filtered)
		if err != nil {
			return nil, err
		}
	} else {
		ctxt, err = h.privatePublishBox1(content, filtered)
		if err != nil {
			return nil, err
		}
	}

	msg, err := h.publish.Publish(ctxt)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("private/publish: pour failed: %w", err)
	}

	level.Info(h.info).Log("new-private", msg.Key().ShortSigil())

	return msg.Key().String(), nil
}

func (h handler) privatePublishBox1(msg []byte, recps []refs.Ref) ([]byte, error) {

	var feeds = make([]refs.FeedRef, len(recps))
	for i, r := range recps {
		fr, ok := r.(refs.FeedRef)
		if !ok {
			return nil, fmt.Errorf("private/publish/box1: argument %d not a feed ref: %T", i, r)
		}
		feeds[i] = fr
	}

	boxedMsg, err := h.mngr.EncryptBox1(msg, feeds...)
	if err != nil {
		return nil, fmt.Errorf("private/publish/box1: failed to box message: %w", err)
	}

	if h.author.Algo() == refs.RefAlgoFeedGabby {
		boxedMsg = append([]byte("box1:"), boxedMsg...)
	}

	return boxedMsg, nil
}

func (h handler) privatePublishBox2(msg []byte, recps []refs.Ref) ([]byte, error) {
	return nil, fmt.Errorf("TODO: get previous")
	// h.publish.Seq().Value()

	// h.publish.Get(latest)
	// msg.Previous

	// TODO:
	prev := refs.MessageRef{}

	return h.mngr.EncryptBox2(msg, prev, recps)
}

func (h handler) handleRead(ctx context.Context, req *muxrpc.Request, snk *muxrpc.ByteSink) error {
	var args []message.CreateHistArgs
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return fmt.Errorf("private/read: failed to decode call arguments: %w", err)
	}

	var qry message.CreateHistArgs

	if len(args) == 1 {
		qry = args[0]

	} else {
		qry.Limit = -1
	}

	// well, sorry - the client lib needs better handling of receiving types
	qry.Keys = true

	src, err := h.read.Query(
		margaret.Gte(qry.Seq),
		margaret.Limit(int(qry.Limit)),
		margaret.Live(qry.Live))
	if err != nil {
		return fmt.Errorf("private/read: failed to create query: %w", err)
	}

	err = luigi.Pump(ctx, transform.NewKeyValueWrapper(snk, qry.Keys), src)
	if err != nil {
		return fmt.Errorf("private/read: message pump failed: %w", err)
	}
	req.Close()
	return nil
}
