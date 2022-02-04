// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package transform

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/encodedTime"

	"go.cryptoscope.co/ssb/message/multimsg"
	refs "go.mindeco.de/ssb-refs"
)

// NewKeyValueWrapper turns a value into a key-value message.
// If keyWrap is true, it sends the JSON of the ssb.KeyValueRaw value on the passed ByteSink.
func NewKeyValueWrapper(mw *muxrpc.ByteSink, keyWrap bool) luigi.Sink {

	noNulled := mfr.FilterFunc(func(ctx context.Context, v interface{}) (bool, error) {
		switch tv := v.(type) {
		case error:
			if margaret.IsErrNulled(tv) {
				return false, nil
			}
		case margaret.SeqWrapper:

			sv := tv.Value()

			err, ok := sv.(error)
			if !ok {
				return true, nil
			}
			if margaret.IsErrNulled(err) {
				return false, nil
			}
		}

		return true, nil
	})

	mw.SetEncoding(muxrpc.TypeJSON)

	mapToKV := luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			if luigi.IsEOS(err) {
				return mw.Close()
			}
			return mw.CloseWithError(err)
		}

		var seqWrap margaret.SeqWrapper

		var abs refs.Message
		switch tv := v.(type) {
		case json.RawMessage:
			_, err = mw.Write(tv)
			return err
		case refs.Message:
			abs = tv
		case margaret.SeqWrapper:
			seqWrap = tv

			sv := tv.Value()
			var ok bool
			abs, ok = sv.(refs.Message)
			if !ok {
				return fmt.Errorf("kvwrap: wrong message type in seqWrapper - got %T", sv)
			}
		default:
			return fmt.Errorf("failed to find message in empty interface(%T)", v)
		}

		if !keyWrap {
			// skip re-encoding in some cases
			if mm, ok := abs.(*multimsg.MultiMessage); ok {
				leg, ok := mm.AsLegacy()
				if ok {
					body := leg.Raw_
					_, err = mw.Write(body)
					return err
				}
			}
			if mm, ok := abs.(multimsg.MultiMessage); ok {
				leg, ok := mm.AsLegacy()
				if ok {
					body := leg.Raw_
					_, err = mw.Write(body)
					return err
				}
			}

			body := abs.ValueContentJSON()
			_, err = mw.Write(body)
			return err
		}

		var kv refs.KeyValueRaw
		kv.Key_ = abs.Key()
		kv.Value = *abs.ValueContent()
		kv.Timestamp = encodedTime.Millisecs(abs.Received())

		if seqWrap == nil {
			kvMsg, err := json.Marshal(kv)
			if err != nil {
				return fmt.Errorf("kvwrap: failed to k:v map message: %w", err)
			}
			_, err = mw.Write(kvMsg)
			return err
		}

		type sewWrapped struct {
			Value interface{} `json:"value"`
			Seq   int64       `json:"seq"`
		}

		sw := sewWrapped{
			Value: kv,
			Seq:   seqWrap.Seq(),
		}
		kvMsg, err := json.Marshal(sw)
		if err != nil {
			return fmt.Errorf("kvwrap: failed to k:v map message: %w", err)
		}
		_, err = mw.Write(kvMsg)
		return err
	})

	return mfr.SinkFilter(mapToKV, noNulled)
}
