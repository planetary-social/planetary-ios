// SPDX-License-Identifier: MIT

package transform

import (
	"context"
	"encoding/json"

	"github.com/cryptix/go/encodedTime"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"

	"go.cryptoscope.co/ssb"
)

func NewKeyValueWrapper(snk luigi.Sink, wrap bool) luigi.Sink {

	noNulled := mfr.FilterFunc(func(ctx context.Context, v interface{}) (bool, error) {
		if err, ok := v.(error); ok {
			if margaret.IsErrNulled(err) {
				return false, nil
			}
			return false, err
		}
		return true, nil
	})
	toJSON := mfr.SinkMap(snk, func(ctx context.Context, v interface{}) (interface{}, error) {
		abs, ok := v.(ssb.Message)
		if !ok {
			seqWrap, ok := v.(margaret.SeqWrapper)
			if !ok {
				return nil, errors.Errorf("kvwrap: also not a seqWrapper - got %T", v)
			}

			sv := seqWrap.Value()
			abs, ok = sv.(ssb.Message)
			if !ok {
				return nil, errors.Errorf("kvwrap: wrong message type in seqWrapper - got %T", sv)
			}
		}

		if !wrap {
			return json.RawMessage(abs.ValueContentJSON()), nil
		}

		var kv ssb.KeyValueRaw
		kv.Key_ = abs.Key()
		kv.Value = *abs.ValueContent()
		kv.Timestamp = encodedTime.Millisecs(abs.Received())
		kvMsg, err := json.Marshal(kv)
		if err != nil {
			return nil, errors.Wrapf(err, "kvwrap: failed to k:v map message")
		}

		return json.RawMessage(kvMsg), nil
	})

	return mfr.SinkFilter(toJSON, noNulled)
}
