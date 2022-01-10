// SPDX-License-Identifier: MIT

package multimsg

import (
	"io"
	"time"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"

	"go.cryptoscope.co/ssb"
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

func (wl WrappedLog) Append(val interface{}) (margaret.Seq, error) {
	if mm, ok := val.(*MultiMessage); ok {
		return wl.AlterableLog.Append(*mm)
	}

	var mm MultiMessage

	if osm, ok := val.(legacy.OldStoredMessage); ok {
		mm.tipe = Legacy
		mm.Message = &legacy.StoredMessage{
			Author_:    osm.Author,
			Previous_:  osm.Previous,
			Key_:       osm.Key,
			Sequence_:  osm.Sequence,
			Timestamp_: osm.Timestamp,
			Raw_:       osm.Raw,
		}
		return wl.AlterableLog.Append(mm)
	}

	abs, ok := val.(ssb.Message)
	if !ok {
		return margaret.SeqEmpty, errors.Errorf("wrappedLog: not a ssb.Message: %T", val)
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
	default:
		return margaret.SeqEmpty, errors.Errorf("wrappedLog: unsupported message type: %T", val)
	}

	return wl.AlterableLog.Append(mm)
}
