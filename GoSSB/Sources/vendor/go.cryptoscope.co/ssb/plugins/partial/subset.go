// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package partial

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"

	"github.com/dgraph-io/sroar"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb/query"
	refs "go.mindeco.de/ssb-refs"
)

type getSubsetHandler struct {
	queryPlaner *query.SubsetPlaner

	rxLog margaret.Log
}

func (h getSubsetHandler) HandleSource(ctx context.Context, req *muxrpc.Request, sink *muxrpc.ByteSink) error {

	var (
		args []json.RawMessage
		arg  query.SubsetOperation
		opts query.SubsetOptions
	)

	err := json.Unmarshal(req.RawArgs, &args)
	if err != nil {
		return err
	}
	nArgs := len(args)
	if nArgs < 1 {
		return fmt.Errorf("expected one arguemnt got %d", nArgs)
	}

	err = json.Unmarshal(args[0], &arg)
	if err != nil {
		return err
	}

	if nArgs > 1 {
		err = json.Unmarshal(args[1], &opts)
		if err != nil {
			return err
		}
	} else { // set defaults
		opts.PageLimit = -1
		opts.Keys = true
	}

	resulting, err := h.queryPlaner.QuerySubsetBitmap(arg)
	if err != nil {
		return fmt.Errorf("failed to send query result to peer: %w", err)
	}

	if resulting == nil {
		sink.Close()
		return nil
	}

	sink.SetEncoding(muxrpc.TypeJSON)
	// iterate over the combined set of bitmaps
	var (
		it *sroar.Iterator

		buf bytes.Buffer
		enc = json.NewEncoder(&buf)
	)

	if opts.Descending {
		it = resulting.NewReverseIterator()
	} else {
		it = resulting.NewIterator()
	}

	for it.HasNext() {

		v := it.Next()
		msgv, err := h.rxLog.Get(int64(v))
		if err != nil {
			break
		}

		msg, ok := msgv.(refs.Message)
		if !ok {
			return fmt.Errorf("invalid msg type %T", msgv)
		}

		if opts.Keys {
			buf.Reset()

			var kv refs.KeyValueRaw
			kv.Key_ = msg.Key()
			kv.Value = *msg.ValueContent()

			if err := enc.Encode(kv); err != nil {
				return fmt.Errorf("failed to encode json: %w", err)
			}

			if _, err = buf.WriteTo(sink); err != nil {
				return fmt.Errorf("failed to send json data: %w", err)
			}
		} else {
			_, err = sink.Write(msg.ValueContentJSON())
			if err != nil {
				return fmt.Errorf("failed to send json data: %w", err)
			}
		}

		if opts.PageLimit >= 0 {
			opts.PageLimit--
			if opts.PageLimit == 0 {
				break
			}
		}
	}

	sink.Close()
	return nil
}
