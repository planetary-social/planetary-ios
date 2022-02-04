// SPDX-FileCopyrightText: 2021 The go-metafeed Authors
//
// SPDX-License-Identifier: MIT

package metafeed

import (
	"crypto/sha256"
	"encoding"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/zeebo/bencode"
	"go.mindeco.de/encodedTime"
	"golang.org/x/crypto/ed25519"

	"github.com/ssb-ngi-pointer/go-metafeed/internal/sign"
	refs "go.mindeco.de/ssb-refs"
)

// Message is used to create the (un)marshal a message to and from bencode while also acting as refs.Message for the rest of the ssb system.
type Message struct {
	Data bencode.RawMessage

	Signature []byte

	payload *Payload
}

var (
	_ bencode.Marshaler   = (*Message)(nil)
	_ bencode.Unmarshaler = (*Message)(nil)
)

// MarshalBencode turns data and signature into an bencode array [content, signature]
func (msg *Message) MarshalBencode() ([]byte, error) {
	return bencode.EncodeBytes([]interface{}{
		msg.Data,
		msg.Signature,
	})
}

// UnmarshalBencode expects a benocded array of [content, signature]
func (msg *Message) UnmarshalBencode(input []byte) error {
	if len(input) > maxMessageSize {
		return errors.New("metafeed: message too big")
	}

	var raw []bencode.RawMessage
	err := bencode.DecodeBytes(input, &raw)
	if err != nil {
		return fmt.Errorf("failed to decode raw Message array: %w", err)
	}

	if n := len(raw); n != 2 {
		return fmt.Errorf("metafeed/Message: expected two elemnts in the array, got %d", n)
	}

	// just take the data as is (that it's valid bencode was settled by the first decode pass)
	msg.Data = raw[0]

	// make sure it's a valid byte string
	err = bencode.DecodeBytes(raw[1], &msg.Signature)
	if err != nil {
		return fmt.Errorf("metafeed/Message: failed to decode signature portion: %w", err)
	}

	if n := len(msg.Signature); n != ed25519.SignatureSize+2 {
		return fmt.Errorf("metafeed/Message: expected %d bytes of signture - only got %d", ed25519.SignatureSize+2, n)
	}

	return nil
}

// for storage
var (
	_ encoding.BinaryMarshaler   = (*Message)(nil)
	_ encoding.BinaryUnmarshaler = (*Message)(nil)
)

// MarshalBinary for now, calls the bencode versions (performance profiling pending)
func (msg *Message) MarshalBinary() ([]byte, error) {
	return msg.MarshalBencode()
}

// UnmarshalBinary for now, calls the bencode versions (performance profiling pending)
func (msg *Message) UnmarshalBinary(input []byte) error {
	return msg.UnmarshalBencode(input)
}

// Verify returns true if the Message was signed by the author specified by the meta portion of the message
func (msg *Message) Verify(hmacKey *[32]byte) bool {
	if err := msg.getPayload(); err != nil {
		return false
	}
	pubKey := msg.payload.Author.PubKey()

	return sign.Verify(msg.Data, msg.Signature, pubKey, hmacKey)
}

// Payload returns the message payload inside the data portion of the Message object.
func (msg *Message) Payload() (Payload, error) {
	if err := msg.getPayload(); err != nil {
		return Payload{}, err
	}
	return *msg.payload, nil
}

func (msg *Message) getPayload() error {
	if msg.payload != nil {
		return nil
	}
	var p Payload
	if err := p.UnmarshalBencode(msg.Data); err != nil {
		return err
	}
	msg.payload = &p
	return nil
}

// go-ssb compatability

var _ refs.Message = (*Message)(nil)

// Key returns the hash reference of the message
func (msg *Message) Key() refs.MessageRef {

	// TODO: do this lazy and cache the result
	bytes, err := msg.MarshalBencode()
	if err != nil {
		panic(err)
	}

	h := sha256.New()
	h.Write(bytes)

	msgKey, err := refs.NewMessageRefFromBytes(h.Sum(nil), refs.RefAlgoMessageBendyButt)
	if err != nil {
		panic(err)
	}
	return msgKey
}

// Seq returns the sequence of th message
func (msg *Message) Seq() int64 {
	err := msg.getPayload()
	if err != nil {
		log.Println("metafeed/verify payload decoding failed:", err)
		return -1
	}
	return int64(msg.payload.Sequence)
}

// Author returns the author who signed the message
func (msg *Message) Author() refs.FeedRef {
	err := msg.getPayload()
	if err != nil {
		panic(err)
	}
	return msg.payload.Author
}

// Previous return nil for the first message and otherwise the hash reference of the previous message
func (msg *Message) Previous() *refs.MessageRef {
	err := msg.getPayload()
	if err != nil {
		panic(err)
	}
	if msg.payload.Sequence == 1 {
		return nil
	}
	return msg.payload.Previous
}

// Received needs to be repalced by the database (this spoofs it as the calimed timestamp)
func (msg *Message) Received() time.Time {
	log.Println("received time is spoofed to claimed")
	return msg.Claimed()
}

// Claimed returns the time the message claims as it's timestamp
func (msg *Message) Claimed() time.Time {
	err := msg.getPayload()
	if err != nil {
		panic(err)
	}
	return msg.payload.Timestamp
}

// ContentBytes returns the pure bencoded content portion of the message
func (msg *Message) ContentBytes() []byte {
	var arr []bencode.RawMessage
	err := bencode.DecodeBytes(msg.Data, &arr)
	if err != nil {
		panic(err)
	}

	return arr[4]
}

// ValueContent returns a ssb.Value that can be represented as JSON.
// Note that it's signature is useless for verification in this form.
// Get the whole Message message and use msg.Verify()
func (msg *Message) ValueContent() *refs.Value {
	err := msg.getPayload()
	if err != nil {
		panic(err)
	}
	var val refs.Value
	if msg.payload.Sequence > 1 {
		val.Previous = msg.payload.Previous
	}

	val.Author = msg.payload.Author
	val.Sequence = int64(msg.payload.Sequence)
	val.Hash = "metafeed-v1"
	val.Signature = base64.StdEncoding.EncodeToString(msg.Signature) + ".metafeed-v1.sig.ed25519"
	val.Timestamp = encodedTime.Millisecs(msg.Claimed())

	// TODO: peek at first byte (tfk indicating box2 for instance)
	var helper interface{}
	err = bencode.DecodeBytes(msg.payload.Content, &helper)
	if err != nil {
		panic(err)
	}

	val.Content, err = json.Marshal(helper)
	if err != nil {
		panic(err)
	}

	return &val
}

// ValueContentJSON encodes the Message into JSON like a normal SSB message.
func (msg *Message) ValueContentJSON() json.RawMessage {
	jsonB, err := json.Marshal(msg.ValueContent())
	if err != nil {
		panic(err.Error())
	}

	return jsonB
}
