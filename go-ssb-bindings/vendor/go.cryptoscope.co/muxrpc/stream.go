// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"sync"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/codec"

	"github.com/pkg/errors"
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

// how should a stream be able to be used
type streamCapability uint

func (c streamCapability) String() string {
	switch c {
	case streamCapNone:
		return "streamCap:none"
	case streamCapOnce:
		return "streamCap:once"
	case streamCapMultiple:
		return "streamCap:multiple"
	default:
		panic(fmt.Sprintf("invalid stream capability: %d", c))
	}
}

const (
	streamCapNone     streamCapability = iota // can't be used
	streamCapOnce                             // can be once
	streamCapMultiple                         // can be used multiple times
)

func newStream(src luigi.Source, sink luigi.Sink, req int32, ins, outs streamCapability) Stream {
	return &stream{
		pktSrc:    src,
		pktSink:   sink,
		req:       req,
		closeCh:   make(chan struct{}),
		closeOnce: &sync.Once{},
		inCap:     ins,
		outCap:    outs,
	}
}

// stream implements the Stream.
type stream struct {
	l sync.Mutex

	pktSrc  luigi.Source
	pktSink luigi.Sink

	tipe      interface{}
	req       int32
	closeCh   chan struct{}
	closeOnce *sync.Once
	closed    bool

	inCap, outCap streamCapability
}

// WithType makes the stream unmarshal JSON into values of type tipe
func (str *stream) WithType(tipe interface{}) {
	str.l.Lock()
	defer str.l.Unlock()

	str.tipe = tipe
}

// WithReq makes the stream use req as request ID for outbound messages.
func (str *stream) WithReq(req int32) {
	str.l.Lock()
	defer str.l.Unlock()

	str.req = req
}

// Next returns the next incoming value on the stream
func (str *stream) Next(ctx context.Context) (interface{}, error) {

	switch str.inCap {
	case streamCapNone:
		return nil, ErrStreamNotReadable
	}

	// cancellation
	ctx, cancel := withError(ctx, luigi.EOS{})
	defer cancel()
	go func() {
		select {
		case <-str.closeCh:
			cancel()
		case <-ctx.Done():
		}
	}()

	vpkt, err := str.pktSrc.Next(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "muxrpc: error reading from packet source")
	}

	pkt, ok := vpkt.(*codec.Packet)
	if !ok {
		return nil, errors.Errorf("muxrpc: unexpected vpkt value: %v %T", vpkt, vpkt)
	}

	if pkt.Flag.Get(codec.FlagEndErr) {
		// TODO: return error body?
		// log.Println("muxrpc: stream %d got error: %q", pkt.Req, string(pkt.Body))
		return nil, luigi.EOS{}
	}

	var dst interface{}
	if pkt.Flag.Get(codec.FlagJSON) {
		var ptrType bool

		if str.tipe != nil {
			t := reflect.TypeOf(str.tipe)
			if t.Kind() == reflect.Ptr {
				ptrType = true
				t = t.Elem()
			}

			dst = reflect.New(t).Interface()
		} else {
			ptrType = true
		}

		err := json.Unmarshal(pkt.Body, &dst)
		if err != nil {
			return nil, errors.Wrap(err, "error unmarshaling json")
		}

		if !ptrType {
			dst = reflect.ValueOf(dst).Elem().Interface()
		}
	} else if pkt.Flag.Get(codec.FlagString) {
		dst = string(pkt.Body)
	} else {
		dst = []byte(pkt.Body)
	}

	return dst, nil
}

// Pour sends a message on the stream
func (str *stream) Pour(ctx context.Context, v interface{}) error {
	var (
		pkt *codec.Packet
		err error
	)

	var (
		isStream bool
	)
	switch str.outCap {
	case streamCapNone:
		return ErrStreamNotWritable

	case streamCapMultiple:
		isStream = true
	}

	// cancellation
	ctx, cancel := withError(ctx, errSinkClosed)
	defer cancel()
	go func() {
		select {
		case <-str.closeCh:
			cancel()
		case <-ctx.Done():
		}
	}()

	if body, ok := v.(codec.Body); ok {
		pkt = newRawPacket(isStream, str.req, body)
	} else if body, ok := v.(string); ok {
		pkt = newStringPacket(isStream, str.req, body)
	} else {
		pkt, err = newJSONPacket(isStream, str.req, v)
		if err != nil {
			return errors.Wrap(err, "error building json packet")
		}
	}

	err = str.pktSink.Pour(ctx, pkt)
	if err != nil {
		return errors.Wrap(err, "error pouring to packet sink")
	}

	return nil
}

// Close closes the stream and sends the EndErr message.
func (str *stream) Close() error {
	return str.CloseWithError(luigi.EOS{})
}

// Close closes the stream and sends the EndErr message.
func (str *stream) CloseWithError(closeErr error) error {
	if str.outCap == streamCapOnce && !str.closed {
		return str.doCloseWithError(closeErr)
	}

	if str.outCap != streamCapMultiple {
		return ErrStreamNotClosable
	}
	return str.doCloseWithError(closeErr)
}

func (str *stream) doCloseWithError(closeErr error) error {
	var isStream bool
	if str.inCap == streamCapMultiple {
		isStream = true
	}
	if str.outCap == streamCapMultiple {
		isStream = true
	}

	str.l.Lock()
	defer str.l.Unlock()

	if str.closed {
		if luigi.IsEOS(closeErr) {
			return nil
		}
		return errors.Wrapf(os.ErrClosed, "muxrpc/stream(%d): already closed (wanted to close with: %v)", str.req, closeErr)
	}

	if closeErr == ErrSessionTerminated {
		close(str.closeCh)
		str.closed = true
		return nil
	}

	var (
		pkt *codec.Packet
		err error
	)

	if closeErr == nil || luigi.IsEOS(errors.Cause(closeErr)) {
		pkt = newEndOkayPacket(str.req, isStream)
	} else {
		pkt, err = newEndErrPacket(str.req, isStream, closeErr)
		if err != nil {
			return errors.Wrap(err, "error building error packet")
		}
	}

	str.closeOnce.Do(func() {
		close(str.closeCh)
		str.closed = true

		err = str.pktSink.Pour(context.TODO(), pkt)
	})

	if IsSinkClosed(err) || isAlreadyClosed(err) {
		// log.Printf("muxrpc: stream(%d) sink closed", str.req)
		return nil
	}

	return errors.Wrapf(err, "muxrpc/stream(%d): failed to close with err: %s", str.req, closeErr)
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
		return nil, errors.Wrap(err, "error marshaling value")
	}

	return &codec.Packet{
		Flag: flag,
		Req:  req,
		Body: codec.Body(body),
	}, nil
}

var trueBytes = []byte{'t', 'r', 'u', 'e'}

func newEndOkayPacket(req int32, stream bool) *codec.Packet {
	pkt := codec.Packet{
		Req:  req,
		Flag: codec.FlagJSON | codec.FlagEndErr,
		Body: trueBytes,
	}
	if stream {
		pkt.Flag |= codec.FlagStream
	}
	return &pkt
}

func newEndErrPacket(req int32, stream bool, err error) (*codec.Packet, error) {
	body, err := json.Marshal(CallError{
		Message: err.Error(),
		Name:    "Error",
	})
	if err != nil {
		return nil, errors.Wrap(err, "error marshaling value")
	}
	pkt := codec.Packet{
		Req:  req,
		Flag: codec.FlagJSON | codec.FlagEndErr,
		Body: body,
	}
	if stream {
		pkt.Flag |= codec.FlagStream
	}
	return &pkt, nil
}
