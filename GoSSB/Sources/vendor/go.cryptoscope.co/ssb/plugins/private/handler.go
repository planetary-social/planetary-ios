// SPDX-License-Identifier: MIT

package private

import (
	"context"
	"encoding/json"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/ssb/internal/transform"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/private"

	"go.cryptoscope.co/ssb"

	"github.com/cryptix/go/logging"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"
)

type handler struct {
	info logging.Interface

	publish ssb.Publisher
	read    margaret.Log
}

func (h handler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	var closed bool
	checkAndClose := func(err error) {
		if err != nil {
			h.info.Log("event", "closing", "method", req.Method, "err", err)
		}
		if err != nil {
			closed = true
			closeErr := req.Stream.CloseWithError(err)
			err := errors.Wrapf(closeErr, "error closeing request")
			if err != nil {
				h.info.Log("event", "closing", "method", req.Method, "err", err)
			}
		}
	}

	defer func() {
		if !closed {
			err := errors.Wrapf(req.Stream.Close(), "gossip: error closing call")
			if err != nil {
				h.info.Log("event", "closing", "method", req.Method, "err", err)
			}
		}
	}()

	switch req.Method.String() {

	case "private.publish":
		if req.Type == "" {
			req.Type = "async"
		}
		if n := len(req.Args()); n != 2 {
			req.CloseWithError(errors.Errorf("private/publish: bad request. expected 2 argument got %d", n))
			return
		}

		msg, err := json.Marshal(req.Args()[0])
		if err != nil {
			req.CloseWithError(errors.Wrap(err, "failed to encode message"))
			return
		}

		rcps, ok := req.Args()[1].([]interface{})
		if !ok {
			req.CloseWithError(errors.Errorf("private/publish: wrong argument type. expected []strings but got %T", req.Args()[1]))
			return
		}

		rcpsRefs := make([]*ssb.FeedRef, len(rcps))
		for i, rv := range rcps {
			rstr, ok := rv.(string)
			if !ok {
				req.CloseWithError(errors.Errorf("private/publish: wrong argument type. expected strings but got %T", rv))
				return
			}
			rcpsRefs[i], err = ssb.ParseFeedRef(rstr)
			if err != nil {
				req.CloseWithError(errors.Wrapf(err, "private/publish: failed to parse recp %d", i))
				return
			}
		}

		ref, err := h.privatePublish(msg, rcpsRefs)
		if err != nil {
			req.CloseWithError(err)
			return
		}

		err = req.Return(ctx, ref)
		if err != nil {
			h.info.Log("event", "error", "msg", "cound't return new msg ref")
			return
		}
		h.info.Log("published", ref.Ref())

		return

	case "private.read":
		if req.Type != "source" {
			checkAndClose(errors.Errorf("private.read: wrong request type. %s", req.Type))
			return
		}
		h.privateRead(ctx, req)

	default:
		checkAndClose(errors.Errorf("private: unknown command: %s", req.Method))
	}
}

func (h handler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}

func (h handler) privateRead(ctx context.Context, req *muxrpc.Request) {
	var qry message.CreateHistArgs

	args := req.Args()
	if len(args) > 0 {

		switch v := args[0].(type) {
		case map[string]interface{}:
			q, err := message.NewCreateHistArgsFromMap(v)
			if err != nil {
				req.CloseWithError(errors.Wrap(err, "privateRead: bad request"))
				return
			}
			qry = *q
		default:
			req.CloseWithError(errors.Errorf("privateRead: invalid argument type %T", args[0]))
			return
		}

		if qry.Live {
			qry.Limit = -1
		}
	} else {
		qry.Limit = -1
	}

	// well, sorry - the client lib needs better handling of receiving types
	qry.Keys = true

	src, err := h.read.Query(
		margaret.Gte(margaret.BaseSeq(qry.Seq)),
		margaret.Limit(int(qry.Limit)),
		margaret.Live(qry.Live))
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "private/read: failed to create query"))
		return
	}

	err = luigi.Pump(ctx, transform.NewKeyValueWrapper(req.Stream, qry.Keys), src)
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "private/read: message pump failed"))
		return
	}
	req.Close()
}

func (h handler) privatePublish(msg []byte, recps []*ssb.FeedRef) (*ssb.MessageRef, error) {
	boxedMsg, err := private.Box(msg, recps...)
	if err != nil {
		return nil, errors.Wrap(err, "private/publish: failed to box message")

	}

	ref, err := h.publish.Publish(boxedMsg)
	if err != nil {
		return nil, errors.Wrap(err, "private/publish: pour failed")

	}

	return ref, nil
}
