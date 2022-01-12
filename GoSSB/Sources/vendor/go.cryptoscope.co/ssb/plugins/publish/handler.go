// SPDX-License-Identifier: MIT

package publish

import (
	"context"

	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb"
)

type handler struct {
	publish ssb.Publisher
	rootLog margaret.Log // to get the key back
	info    logging.Interface
}

func (h handler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	if n := req.Method.String(); n != "publish" {
		req.CloseWithError(errors.Errorf("publish: bad request name: %s", n))
		return
	}

	args := req.Args()
	if n := len(args); n != 1 {
		req.CloseWithError(errors.Errorf("publish: bad request. expected 1 argument got %d", n))
		return
	}

	ref, err := h.publish.Publish(args[0])
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "publish: pour failed"))
		return
	}

	level.Info(h.info).Log("event", "published message", "refKey", ref.ShortRef())

	err = req.Return(ctx, ref.Ref())
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "publish: return failed"))
		return
	}
}

func (h handler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}
