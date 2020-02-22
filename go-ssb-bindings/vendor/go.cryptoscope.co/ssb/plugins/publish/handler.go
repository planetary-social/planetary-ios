// SPDX-License-Identifier: MIT

package publish

import (
	"context"

	"go.cryptoscope.co/ssb"

	"github.com/cryptix/go/logging"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"
)

type handler struct {
	publish margaret.Log
	rootLog margaret.Log // to get the key back
	info    logging.Interface
}

func (h handler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	if n := req.Method.String(); n != "publish" {
		req.CloseWithError(errors.Errorf("publish: bad request name: %s", n))
		return
	}
	if n := len(req.Args()); n != 1 {
		req.CloseWithError(errors.Errorf("publish: bad request. expected 1 argument got %d", n))
		return
	}

	seq, err := h.publish.Append(req.Args()[0])
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "publish: pour failed"))
		return
	}

	msgv, err := h.rootLog.Get(seq)
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "publish: geting new message back failed"))
		return
	}

	msg, ok := msgv.(ssb.Message)
	if !ok {
		req.CloseWithError(errors.Errorf("publish: unexpected message type: %T", msgv))
		return
	}

	h.info.Log("info", "published new message", "rootSeq", seq.Seq(), "refKey", msg.Key().Ref())

	err = req.Return(ctx, msg.Key().Ref())
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "publish: return failed"))
		return
	}
}

func (h handler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}
