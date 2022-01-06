// SPDX-License-Identifier: MIT

package sbot

import (
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb"
)

func (s Sbot) Get(ref ssb.MessageRef) (ssb.Message, error) {
	getIdx, ok := s.simpleIndex["get"]
	if !ok {
		return nil, errors.Errorf("sbot: get index disabled")
	}
	obs, err := getIdx.Get(s.rootCtx, librarian.Addr(ref.Hash))
	if err != nil {
		return nil, errors.Wrap(err, "sbot/get: failed to get seq val from index")
	}

	v, err := obs.Value()
	if err != nil {
		return nil, errors.Wrap(err, "sbot/get: failed to get current value from obs")
	}

	var seq margaret.Seq
	switch tv := v.(type) {
	case margaret.Seq:
		seq = tv
	case int64:
		if tv < 0 {
			return nil, errors.Errorf("invalid sequence stored in index")
		}
		seq = margaret.BaseSeq(tv)
	default:
		return nil, errors.Errorf("sbot/get: wrong sequence type in index: %T", v)
	}

	storedV, err := s.RootLog.Get(seq)
	if err != nil {
		return nil, errors.Wrap(err, "sbot/get: failed to load message")
	}

	msg, ok := storedV.(ssb.Message)
	if !ok {
		return nil, errors.Errorf("sbot/get: wrong message type in storeage: %T", storedV)
	}

	return msg, nil
}
