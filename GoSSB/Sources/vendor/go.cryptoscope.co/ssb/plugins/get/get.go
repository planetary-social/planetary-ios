// SPDX-License-Identifier: MIT

package get

import (
	"context"
	"fmt"

	"github.com/pkg/errors"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
)

type plugin struct {
	h muxrpc.Handler
}

func (p plugin) Name() string {
	return "get"
}

func (p plugin) Method() muxrpc.Method {
	return muxrpc.Method{"get"}
}

func (p plugin) Handler() muxrpc.Handler {
	return p.h
}

func New(g ssb.Getter) ssb.Plugin {
	return plugin{
		h: handler{g: g},
	}
}

type handler struct {
	g ssb.Getter
}

func (h handler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (h handler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	if len(req.Args()) < 1 {
		req.CloseWithError(errors.Errorf("invalid arguments"))
		return
	}
	var (
		ref *ssb.MessageRef
		err error
	)
	switch v := req.Args()[0].(type) {
	case string:
		ref, err = ssb.ParseMessageRef(v)
	case map[string]interface{}:
		refV, ok := v["key"]
		if !ok {
			req.CloseWithError(errors.Errorf("invalid argument - missing 'key' in map"))
			return
		}
		ref, err = ssb.ParseMessageRef(refV.(string))
	default:
		req.CloseWithError(errors.Errorf("invalid argument type %T", req.Args()[0]))
		return
	}

	if err != nil {
		req.CloseWithError(errors.Wrap(err, "failed to parse arguments"))
		return
	}

	msg, err := h.g.Get(*ref)
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "failed to load message"))
		return
	}

	// var retMsg json.RawMessage
	// if msg.Author.Offchain {
	// 	var tmpMsg message.DeserializedMessage
	// 	tmpMsg.Previous = *msg.Previous
	// 	tmpMsg.Author = *msg.Author
	// 	tmpMsg.Sequence = msg.Sequence
	// 	// tmpMsg.Timestamp = msg. TODO: meh.. need to get the user-timestamp from the raw field
	// 	tmpMsg.Hash = msg.Key.Algo
	// 	tmpMsg.Content = msg.Offchain

	// 	retMsg, err = json.Marshal(tmpMsg)
	// 	if err != nil {
	// 		req.CloseWithError(errors.Wrap(err, "failed to re-wrap offchain message"))
	// 		return
	// 	}
	// } else {
	// retMsg = msg.Raw
	// }
	err = req.Return(ctx, msg.ValueContentJSON())
	if err != nil {
	}
	fmt.Println("get: failed? to return message:", err)

}
