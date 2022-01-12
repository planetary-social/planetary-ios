// SPDX-License-Identifier: MIT

package multimsg

import (
	"bytes"
	"time"

	"github.com/pkg/errors"
	"github.com/ugorji/go/codec"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/message/legacy"
)

type MessageType byte

const (
	Unknown MessageType = iota
	Legacy
	Gabby
)

// MultiMessage attempts to support multiple message formats in the same storage layer
// currently supports Proto and legacy
type MultiMessage struct {
	ssb.Message
	tipe MessageType
	key  *ssb.MessageRef

	// metadata
	received time.Time
}

type ggWithMetadata struct {
	gabbygrove.Transfer
	ReceivedTime time.Time
}

func (mm MultiMessage) MarshalBinary() ([]byte, error) {
	var buf bytes.Buffer
	var mh codec.CborHandle
	mh.StructToArray = true
	enc := codec.NewEncoder(&buf, &mh)
	buf.WriteByte(byte(mm.tipe))
	var err error
	switch mm.tipe {
	case Legacy:
		legacy, ok := mm.AsLegacy()
		if !ok {
			return nil, errors.Errorf("multiMessage: not a legacy message: %T", mm.Message)
		}
		err = enc.Encode(legacy)
	case Gabby:
		var meta ggWithMetadata
		meta.ReceivedTime = mm.Received()
		gabby, ok := mm.AsGabby()
		if !ok {
			return nil, errors.Errorf("multiMessage: wrong type of message: %T", mm.Message)
		}
		meta.Transfer = *gabby
		err = enc.Encode(meta)
	default:
		return nil, errors.Errorf("multiMessage: unsupported message type: %x", mm.tipe)
	}
	return buf.Bytes(), errors.Wrapf(err, "multiMessage(%v): data encoding failed", mm.tipe)
}

func (mm *MultiMessage) UnmarshalBinary(data []byte) error {
	if len(data) < 1 {
		return errors.Errorf("multiMessage: data to short")
	}
	var mh codec.CborHandle
	mh.StructToArray = true
	dec := codec.NewDecoderBytes(data[1:], &mh)

	mm.tipe = MessageType(data[0])
	switch mm.tipe {
	case Legacy:
		var msg legacy.StoredMessage
		err := dec.Decode(&msg)
		if err != nil {
			return errors.Wrap(err, "multiMessage: legacy decoding failed")
		}
		mm.received = msg.Timestamp_
		mm.Message = &msg
		mm.key = msg.Key_
	case Gabby:
		var msg ggWithMetadata
		err := dec.Decode(&msg)
		if err != nil {
			return errors.Wrap(err, "multiMessage: gabby decoding failed")
		}
		mm.received = msg.ReceivedTime
		mm.Message = &msg.Transfer
		mm.key = msg.Key()
	default:
		return errors.Errorf("multiMessage: unsupported message type: %x", mm.tipe)
	}
	return nil
}

func (mm MultiMessage) Received() time.Time {
	return mm.received
}

func (mm MultiMessage) AsLegacy() (*legacy.StoredMessage, bool) {
	if mm.tipe != Legacy {
		return nil, false
	}
	legacy, ok := mm.Message.(*legacy.StoredMessage)
	if !ok {
		return nil, false
	}
	return legacy, true
}

func (mm MultiMessage) AsGabby() (*gabbygrove.Transfer, bool) {
	if mm.tipe != Gabby {
		return nil, false
	}
	gabby, ok := mm.Message.(*gabbygrove.Transfer)
	if !ok {
		return nil, false
	}
	return gabby, true
}

func NewMultiMessageFromLegacy(msg *legacy.StoredMessage) *MultiMessage {
	var mm MultiMessage
	mm.tipe = Legacy
	mm.key = msg.Key_
	mm.Message = msg
	return &mm
}
