// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"runtime/debug"
	"strings"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/v2/codec"
)

// RequestEncoding hides the specifics of codec.Flag
type RequestEncoding uint

// binary, string and JSON are the three supported format types.
// Don't ask me why we have string and binary, this just copies the javascript secifics.
const (
	TypeBinary RequestEncoding = iota
	TypeString
	TypeJSON
)

// IsValid returns false if the type is not known.
func (rt RequestEncoding) IsValid() bool {
	if rt < 0 {
		return false
	}
	if rt > TypeJSON {
		return false
	}
	return true
}

func (rt RequestEncoding) asCodecFlag() (codec.Flag, error) {
	if !rt.IsValid() {
		return 0, fmt.Errorf("muxrpc: invalid request encoding %d", rt)
	}
	switch rt {
	case TypeBinary:
		return 0, nil
	case TypeString:
		return codec.FlagString, nil
	case TypeJSON:
		return codec.FlagJSON, nil
	default:
		return 0, fmt.Errorf("muxrpc: invalid request encoding %d", rt)
	}
}

// Method defines the name of the endpoint.
type Method []string

// UnmarshalJSON decodes the
func (m *Method) UnmarshalJSON(d []byte) error {
	var newM []string

	err := json.Unmarshal(d, &newM)
	if err != nil {
		// ugly 'manifest' hack. everything else is an array of strings (ie ['whoami'])
		var meth string
		err := json.Unmarshal(d, &meth)
		if err != nil {
			return fmt.Errorf("muxrpc/method: error decoding packet: %w", err)
		}
		newM = Method{meth}
	}
	*m = newM
	return nil
}

func (m Method) String() string {
	return strings.Join(m, ".")
}

// Request assembles the state of an RPC call
type Request struct {
	// Stream is a legacy adapter for luigi-powered streams
	Stream Stream `json:"-"`

	// Method is the name of the called function
	Method Method `json:"name"`

	// Args contains the call arguments
	RawArgs json.RawMessage `json:"args"`

	// Type is the type of the call, i.e. async, sink, source or duplex
	Type CallType `json:"type"`

	// luigi-less iterators
	sink   *ByteSink
	source *ByteSource

	// same as packet.Req - the numerical identifier for the stream
	id int32

	// used to stop producing more data on this request
	// the calling sight might tell us they had enough of this stream
	abort context.CancelFunc

	remoteAddr net.Addr
	endpoint   *rpc
}

// Endpoint returns the client instance to start new calls. Mostly usefull inside handlers.
func (req Request) Endpoint() Endpoint { return req.endpoint }

// RemoteAddr returns the netwrap'ed network adddress of the underlying connection. This is usually a pair of secretstream.Addr and TCP
func (req Request) RemoteAddr() net.Addr { return req.remoteAddr }

// ResponseSink returns the response writer for incoming source requests.
func (req *Request) ResponseSink() (*ByteSink, error) {
	if req.Type != "source" && req.Type != "duplex" {
		return nil, ErrWrongStreamType{req.Type}
	}
	return req.sink, nil
}

// ResponseSource returns the reader for incoming data of sink or duplex calls.
func (req *Request) ResponseSource() (*ByteSource, error) {
	if req.Type != "sink" && req.Type != "duplex" {
		return nil, ErrWrongStreamType{req.Type}
	}
	return req.source, nil
}

// Args is a legacy stub to get the unmarshaled json arguments
func (req *Request) Args() []interface{} {
	fmt.Println("[muxrpc/deprecation] warning: please use RawArgs where ever possible")
	debug.PrintStack()
	var v []interface{}
	json.Unmarshal(req.RawArgs, &v)
	return v
}

// Return is a helper that returns on an async call
func (req *Request) Return(ctx context.Context, v interface{}) error {
	if req.Type != "async" && req.Type != "sync" {
		return fmt.Errorf("cannot return value on %q stream", req.Type)
	}

	var b []byte
	switch tv := v.(type) {

	case string:
		req.sink.SetEncoding(TypeString)

		b = []byte(tv)

	default:
		req.sink.SetEncoding(TypeJSON)

		var err error
		b, err = json.Marshal(v)
		if err != nil {
			return fmt.Errorf("muxrpc: error marshaling return value: %w", err)
		}
	}

	if _, err := req.sink.Write(b); err != nil {
		return fmt.Errorf("muxrpc: error writing return value: %w", err)
	}

	return nil
}

// CloseWithError is used to close an ongoing request. Ie instruct the remote to stop sending data
// or notify it that a stream couldn't be fully filled because of an error
func (req *Request) CloseWithError(cerr error) error {
	if cerr == nil || errors.Is(cerr, io.EOF) || errors.Is(cerr, luigi.EOS{}) {
		req.source.Cancel(nil)
		req.sink.Close()
	} else {
		req.source.Cancel(cerr)
		req.sink.CloseWithError(cerr)
	}
	// this is a bit ugly but CloseWithError() is the function that HandlerMux uses when replying with "no such command"
	req.endpoint.closeStream(req, cerr)
	return nil
}

// Close closes the stream with io.EOF
func (req *Request) Close() error {
	return req.CloseWithError(io.EOF)
}

// CallType is the type of a call
type CallType string

// Flags returns the packet flags of the respective call type
func (t CallType) Flags() codec.Flag {
	switch t {
	case "source", "sink", "duplex":
		return codec.FlagStream
	default:
		return 0
	}
}
