// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package publish

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"sync"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/private"
	refs "go.mindeco.de/ssb-refs"
)

type handler struct {
	info logging.Interface

	publishMu *sync.Mutex
	publish   ssb.Publisher
	authorLog margaret.Log // for box2 previous

	boxer *private.Manager
}

func (h *handler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	h.publishMu.Lock()
	defer h.publishMu.Unlock()

	if n := req.Method.String(); n != "publish" {
		return nil, fmt.Errorf("publish: bad request name: %s", n)
	}

	var args []json.RawMessage
	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return nil, err
	}
	if n := len(args); n != 1 {
		return nil, fmt.Errorf("publish: bad request. expected 1 argument got %d", n)
	}

	// check if we should encrypt the content
	var contentWithRefs struct {
		Recps []refs.AnyRef
	}
	err = json.Unmarshal(args[0], &contentWithRefs)
	if err != nil {
		return nil, err
	}

	var content interface{}
	if recps := contentWithRefs.Recps; len(recps) > 0 {
		var useBox2 = false

		// sometimes the go type system is really silly and pedantic.
		// a []typeA where typeA implements interface typeX is not the same as []typeX
		var opagueRefs []refs.Ref
		var feedRefs []refs.FeedRef

		for i, r := range recps {
			if mr, ok := r.IsMessage(); ok && mr.Algo() == refs.RefAlgoCloakedGroup {
				if i != 0 {
					return nil, fmt.Errorf("currently the group needs to be the first recipient")
				}
				useBox2 = true
			}
			if useBox2 {
				opagueRefs = append(opagueRefs, r)
			} else {
				fr, ok := r.IsFeed()
				if !ok {
					return nil, fmt.Errorf("not a feed reference in recps for box1")
				}
				feedRefs = append(feedRefs, fr)
			}
		}

		if useBox2 {
			return nil, fmt.Errorf("TODO: get previous for author")
			prev := refs.MessageRef{}
			ciphertext, err := h.boxer.EncryptBox2(args[0], prev, opagueRefs)
			if err != nil {
				return nil, err
			}
			content = base64.StdEncoding.EncodeToString(ciphertext) + ".box2"
		} else {
			ciphertext, err := h.boxer.EncryptBox1(args[0], feedRefs...)
			if err != nil {
				return nil, err
			}
			content = base64.StdEncoding.EncodeToString(ciphertext) + ".box"
		}
		if err != nil {
			return nil, fmt.Errorf("publish: failed to encrypt message (box2:%v recps:%d): %w", useBox2, len(recps), err)
		}
	} else {
		err = json.Unmarshal(args[0], &content)
		if err != nil {
			return nil, err
		}
	}

	msg, err := h.publish.Publish(content)
	if err != nil {
		return nil, fmt.Errorf("publish: pour failed: %w", err)
	}

	level.Info(h.info).Log("event", "published message", "refKey", msg.Key().ShortSigil())

	return msg.Key().String(), nil
}
