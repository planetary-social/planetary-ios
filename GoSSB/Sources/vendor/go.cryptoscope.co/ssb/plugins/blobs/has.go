// SPDX-License-Identifier: MIT

package blobs

import (
	"context"
	"fmt"

	"github.com/cryptix/go/logging"
	"github.com/pkg/errors"

	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
)

type hasHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (hasHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h hasHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	// TODO: push manifest check into muxrpc
	if req.Type == "" {
		req.Type = "async"
	}

	if len(req.Args()) != 1 {
		// TODO: change from generic handlers to typed once (source, sink, async..)
		// async then would have to return a value or an error and not fall into this trap of not closing a stream
		req.Stream.CloseWithError(fmt.Errorf("bad request - wrong args"))
		return
	}

	switch v := req.Args()[0].(type) {
	case string:

		ref, err := ssb.ParseBlobRef(v)
		if err != nil {
			req.Stream.CloseWithError(errors.Wrap(err, "error parsing blob reference"))
			return
		}

		_, err = h.bs.Get(ref)

		has := true

		if err == blobstore.ErrNoSuchBlob {
			has = false
		} else if err != nil {
			err = errors.Wrap(err, "error looking up blob")
			err = req.Stream.CloseWithError(err)
			checkAndLog(h.log, err)
			return
		}

		err = req.Return(ctx, has)
		checkAndLog(h.log, errors.Wrap(err, "error returning value"))

	case []interface{}:
		var has = make([]bool, len(v))

		for k, blobRef := range v {

			blobStr, ok := blobRef.(string)
			if !ok {
				req.Stream.CloseWithError(fmt.Errorf("bad request - unhandled type"))
				return
			}
			ref, err := ssb.ParseBlobRef(blobStr)
			checkAndLog(h.log, errors.Wrap(err, "error parsing blob reference"))
			if err != nil {
				return
			}

			_, err = h.bs.Get(ref)

			has[k] = true

			if err == blobstore.ErrNoSuchBlob {
				has[k] = false
			} else if err != nil {
				err = errors.Wrap(err, "error looking up blob")
				err = req.Stream.CloseWithError(err)
				checkAndLog(h.log, err)
				return
			}

		}

		err := req.Return(ctx, has)
		checkAndLog(h.log, errors.Wrap(err, "error returning value"))

	default:
		req.Stream.CloseWithError(fmt.Errorf("bad request - unhandled type"))
		return
	}

}
