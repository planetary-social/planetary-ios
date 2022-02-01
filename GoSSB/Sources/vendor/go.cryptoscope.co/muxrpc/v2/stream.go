// SPDX-License-Identifier: MIT

package muxrpc

import (
	"encoding/json"
	"fmt"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"

	"go.cryptoscope.co/muxrpc/v2/codec"
)

var (
	ErrStreamNotReadable = errors.New("muxrpc: this stream can not be read from")
	ErrStreamNotWritable = errors.New("muxrpc: this stream can not be written to")
	ErrStreamNotClosable = errors.New("muxrpc: this stream can not be closed")
)

// Stream is a muxrpc stream for the general duplex case.
type Stream interface {
	luigi.Source
	luigi.Sink
	luigi.ErrorCloser

	// WithType tells the stream in what type JSON data should be unmarshalled into
	WithType(tipe interface{})

	// WithReq tells the stream what request number should be used for sent messages
	WithReq(req int32)
}

// newRawPacket crafts a packet with a byte slice as payload
func newRawPacket(stream bool, req int32, body []byte) *codec.Packet {
	var flag codec.Flag

	if stream {
		flag = codec.FlagStream
	}

	return &codec.Packet{
		Flag: flag,
		Req:  req,
		Body: codec.Body(body),
	}
}

// newStringPacket crafts a new packet with string payload
func newStringPacket(stream bool, req int32, body string) *codec.Packet {
	var flag codec.Flag

	if stream {
		flag = codec.FlagStream
	}

	flag |= codec.FlagString

	return &codec.Packet{
		Flag: flag,
		Req:  req,
		Body: codec.Body(body),
	}
}

// newJSONPacket crafts a new packets with JSON payload
func newJSONPacket(stream bool, req int32, v interface{}) (*codec.Packet, error) {
	var flag codec.Flag

	if stream {
		flag = codec.FlagStream
	}

	flag |= codec.FlagJSON

	body, err := json.Marshal(v)
	if err != nil {
		return nil, fmt.Errorf("error marshaling value: %w", err)
	}

	return &codec.Packet{
		Flag: flag,
		Req:  req,
		Body: codec.Body(body),
	}, nil
}

var trueBytes = []byte{'t', 'r', 'u', 'e'}

func newEndOkayPacket(req int32, stream bool) codec.Packet {
	pkt := codec.Packet{
		Req:  req,
		Flag: codec.FlagJSON | codec.FlagEndErr,
		Body: trueBytes,
	}
	if stream {
		pkt.Flag |= codec.FlagStream
	}
	return pkt
}

func newEndErrPacket(req int32, stream bool, err error) (codec.Packet, error) {
	body, err := json.Marshal(CallError{
		Message: err.Error(),
		Name:    "Error",
	})
	if err != nil {
		return codec.Packet{}, fmt.Errorf("error marshaling value: %w", err)
	}
	pkt := codec.Packet{
		Req:  req,
		Flag: codec.FlagJSON | codec.FlagEndErr,
		Body: body,
	}
	if stream {
		pkt.Flag |= codec.FlagStream
	}
	return pkt, nil
}
