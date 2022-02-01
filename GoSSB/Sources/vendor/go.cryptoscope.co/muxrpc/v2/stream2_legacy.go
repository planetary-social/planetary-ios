// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"reflect"

	"go.cryptoscope.co/luigi"

	"go.cryptoscope.co/muxrpc/v2/codec"
)

// AsStream returns a legacy stream adapter for luigi code
func (bs *ByteSource) AsStream() *streamSource {
	// fmt.Println("[muxrpc/deprecation] warning: please use ByteSource where ever possible")
	// debug.PrintStack()
	return &streamSource{
		source: bs,
		tipe:   nil, // nil for defaulting to empty-interface auto-typing
	}
}

type streamSource struct {
	source *ByteSource

	tipe interface{}
}

func (stream *streamSource) Next(ctx context.Context) (interface{}, error) {
	// fmt.Println("[muxrpc/deprecation] warning: please use ByteSink where ever possible")
	// debug.PrintStack()
	if !stream.source.Next(ctx) {
		err := stream.source.Err()
		if err == nil {
			return nil, luigi.EOS{}
		}
		return nil, fmt.Errorf("muxrpc: no more elemts from source: %w", err)
	}

	// TODO: flag is known at creation tyme and doesnt change other then end
	if stream.source.hdrFlag.Get(codec.FlagJSON) {
		var (
			dst     interface{}
			ptrType bool
		)

		if stream.tipe != nil {
			t := reflect.TypeOf(stream.tipe)
			if t.Kind() == reflect.Ptr {
				ptrType = true
				t = t.Elem()
			}
			dst = reflect.New(t).Interface()
		} else {
			ptrType = true
		}

		err := stream.source.Reader(func(rd io.Reader) error {
			err := json.NewDecoder(rd).Decode(&dst)
			if err != nil {
				return fmt.Errorf("muxrpc: failed to decode json from source: %w", err)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}

		if !ptrType {
			dst = reflect.ValueOf(dst).Elem().Interface()
		}
		return dst, nil
	} else if stream.source.hdrFlag.Get(codec.FlagString) {
		buf, err := stream.source.Bytes()
		if err != nil {
			return nil, err
		}
		str := string(buf)
		return str, nil
	} else {
		return stream.source.Bytes()
	}
}

func (stream *streamSource) Pour(ctx context.Context, v interface{}) error {
	err := fmt.Errorf("muxrpc: can't pour into byte source %T", v)
	return err
}

func (stream *streamSource) Close() error {
	return errors.New("muxrpc: can't close byte source?")
}

func (stream *streamSource) CloseWithError(e error) error {
	stream.source.Cancel(e)
	return nil // already closed?
}

// WithType tells the stream in what type JSON data should be unmarshalled into
func (stream *streamSource) WithType(tipe interface{}) {
	// fmt.Printf("muxrpc: chaging marshal type to %T\n", tipe)
	stream.tipe = tipe
}

// WithReq tells the stream what request number should be used for sent messages
func (stream *streamSource) WithReq(req int32) {
	// fmt.Printf("muxrpc: chaging request ID to %d\n", req)
}

// AsStream returns a legacy stream adapter for luigi code
func (bs *ByteSink) AsStream() *streamSink {
	return &streamSink{sink: bs}
}

type streamSink struct{ sink *ByteSink }

func (stream *streamSink) Next(ctx context.Context) (interface{}, error) {
	return nil, errors.New("muxrpc: can't read from a sink")
}

func (stream *streamSink) Pour(ctx context.Context, v interface{}) error {
	// fmt.Println("[muxrpc/deprecation] warning: please use ByteSink where ever possible")
	// debug.PrintStack()
	var err error
	switch tv := v.(type) {
	case []byte:
		_, err = stream.sink.Write(tv)
	case string:
		stream.sink.SetEncoding(TypeString)
		_, err = fmt.Fprint(stream.sink, tv)
	case json.RawMessage:
		stream.sink.SetEncoding(TypeJSON)
		_, err = stream.sink.Write(tv)
	default:
		// fmt.Printf("[legacy stream sink] defaulted on %T\n", v)
		stream.sink.SetEncoding(TypeJSON)
		err = json.NewEncoder(stream.sink).Encode(v)
		if err != nil {
			return fmt.Errorf("muxrpc/legacy: failed pouring to new sink: %w", err)
		}
	}
	return err
}

func (stream *streamSink) Close() error {
	return stream.sink.Close()
}

func (stream *streamSink) CloseWithError(e error) error {
	return stream.sink.CloseWithError(e)
}

// WithType tells the stream in what type JSON data should be unmarshalled into
func (stream *streamSink) WithType(tipe interface{}) {
	// fmt.Printf("muxrpc: chaging marshal type to %T\n", tipe)
}

// WithReq tells the stream what request number should be used for sent messages
func (stream *streamSink) WithReq(req int32) {
	// fmt.Printf("muxrpc/legacy: chaging request ID of sink to %d\n", req)
	stream.sink.pkt.Req = req
}

type streamDuplex struct {
	src *streamSource
	snk *streamSink
}

func (stream *streamDuplex) Next(ctx context.Context) (interface{}, error) {
	return stream.src.Next(ctx)
}

func (stream *streamDuplex) Pour(ctx context.Context, v interface{}) error {
	return stream.snk.Pour(ctx, v)
}

func (stream *streamDuplex) Close() error {
	return stream.snk.Close()
}

func (stream *streamDuplex) CloseWithError(e error) error {
	return stream.snk.CloseWithError(e)
}

// WithType tells the stream in what type JSON data should be unmarshalled into
func (stream *streamDuplex) WithType(tipe interface{}) {
	stream.snk.WithType(tipe)
	stream.src.WithType(tipe)
}

// WithReq tells the stream what request number should be used for sent messages
func (stream *streamDuplex) WithReq(req int32) {
	stream.snk.WithReq(req)
	stream.src.WithReq(req)
}
