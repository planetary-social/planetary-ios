// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package multimsg implements a margaret codec to encode multiple kinds of messages to disk.
// Currently _legacy_ and _gabbygrove_ but should be easily extendable.
package multimsg

import (
	"bytes"
	"encoding/json"
	"fmt"
	"time"

	"github.com/ssb-ngi-pointer/go-metafeed"
	"github.com/ugorji/go/codec"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"

	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message/legacy"
	refs "go.mindeco.de/ssb-refs"
)

type MessageType byte

const (
	Unknown MessageType = iota
	Legacy
	Gabby
	MetaFeed
)

// MultiMessage attempts to support multiple message formats in the same storage layer
// currently supports Proto and legacy
type MultiMessage struct {
	refs.Message
	tipe MessageType
	key  refs.MessageRef

	// metadata
	received time.Time
}

type ggWithMetadata struct {
	gabbygrove.Transfer
	ReceivedTime time.Time
}

type bbWithMetadata struct {
	metafeed.Message
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
			return nil, fmt.Errorf("multiMessage: not a legacy message: %T", mm.Message)
		}
		err = enc.Encode(legacy)

	case Gabby:
		var meta ggWithMetadata
		meta.ReceivedTime = mm.Received()
		gabby, ok := mm.AsGabby()
		if !ok {
			return nil, fmt.Errorf("multiMessage: not a gabbygrove: %T", mm.Message)
		}
		meta.Transfer = *gabby
		err = enc.Encode(meta)

	case MetaFeed:
		var meta bbWithMetadata
		meta.ReceivedTime = mm.Received()
		mf, ok := mm.AsMetaFeed()
		if !ok {
			return nil, fmt.Errorf("multiMessage: not a metafeed: %T", mm.Message)
		}
		meta.Message = *mf
		err = enc.Encode(meta)

	default:
		return nil, fmt.Errorf("multiMessage: unsupported message type: %x", mm.tipe)
	}
	if err != nil {
		return nil, fmt.Errorf("multiMessage(%v): data encoding failed: %w", mm.tipe, err)
	}
	return buf.Bytes(), nil
}

func (mm *MultiMessage) UnmarshalBinary(data []byte) error {
	if len(data) < 1 {
		return fmt.Errorf("multiMessage: data to short")
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
			return fmt.Errorf("multiMessage: legacy decoding failed: %w", err)
		}
		mm.received = msg.Timestamp_
		mm.Message = &msg
		mm.key = msg.Key_.MessageRef

	case Gabby:
		var msg ggWithMetadata
		err := dec.Decode(&msg)
		if err != nil {
			return fmt.Errorf("multiMessage: gabby decoding failed: %w", err)
		}
		mm.received = msg.ReceivedTime
		mm.Message = &msg.Transfer
		mm.key = msg.Key()

	case MetaFeed:
		var msg bbWithMetadata
		err := dec.Decode(&msg)
		if err != nil {
			return fmt.Errorf("multiMessage: metafeed decoding failed: %w", err)
		}
		mm.received = msg.ReceivedTime
		mm.Message = &msg.Message
		mm.key = msg.Key()

	default:
		return fmt.Errorf("multiMessage: unsupported message type: %x", mm.tipe)
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

func (mm MultiMessage) AsMetaFeed() (*metafeed.Message, bool) {
	if mm.tipe != MetaFeed {
		return nil, false
	}
	msg, ok := mm.Message.(*metafeed.Message)
	if !ok {
		return nil, false
	}
	return msg, true
}

func NewMultiMessageFromLegacy(msg *legacy.StoredMessage) *MultiMessage {
	var mm MultiMessage
	mm.tipe = Legacy
	mm.key = msg.Key_.MessageRef
	mm.Message = msg
	return &mm
}

func NewMultiMessageFromKeyValRaw(msg refs.KeyValueRaw, raw json.RawMessage) MultiMessage {
	var mm MultiMessage
	mm.tipe = Legacy
	mm.key = msg.Key_
	sm := &legacy.StoredMessage{
		Author_:    storedrefs.SerialzedFeed{FeedRef: msg.Author()},
		Key_:       storedrefs.SerialzedMessage{MessageRef: msg.Key_},
		Sequence_:  msg.Value.Sequence,
		Timestamp_: msg.Claimed(),
		Raw_:       raw,
	}
	if p := msg.Previous(); p != nil {
		sm.Previous_ = &storedrefs.SerialzedMessage{
			MessageRef: *p,
		}
	}
	mm.Message = sm
	return mm
}
