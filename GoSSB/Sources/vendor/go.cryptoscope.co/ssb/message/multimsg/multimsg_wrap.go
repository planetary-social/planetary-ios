// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package multimsg

import (
	"fmt"
	"io"
	"time"

	"github.com/ssb-ngi-pointer/go-metafeed"
	"go.cryptoscope.co/margaret"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/ssb/message/legacy"
)

type AlterableLog interface {
	margaret.Log
	margaret.Alterer
	io.Closer
}

func NewWrappedLog(in AlterableLog) *WrappedLog {
	return &WrappedLog{
		AlterableLog: in,
		receivedNow:  time.Now,
	}
}

type WrappedLog struct {
	AlterableLog

	// overwriteable for testing
	receivedNow func() time.Time
}

func (wl WrappedLog) Append(val interface{}) (int64, error) {
	if mm, ok := val.(*MultiMessage); ok {
		return wl.AlterableLog.Append(*mm)
	}

	var mm MultiMessage

	abs, ok := val.(refs.Message)
	if !ok {
		return margaret.SeqEmpty, fmt.Errorf("wrappedLog: not a refs.Message: %T", val)
	}

	mm.key = abs.Key()

	switch tv := val.(type) {
	case *legacy.StoredMessage:
		mm.tipe = Legacy
		mm.Message = tv
		tv.Timestamp_ = wl.receivedNow()
	case *gabbygrove.Transfer:
		mm.tipe = Gabby
		mm.Message = tv
		mm.received = wl.receivedNow()
	case *metafeed.Message:
		mm.tipe = MetaFeed
		mm.Message = tv
		mm.received = wl.receivedNow()
	default:
		return margaret.SeqEmpty, fmt.Errorf("wrappedLog: unsupported message type: %T", val)
	}

	return wl.AlterableLog.Append(mm)
}
