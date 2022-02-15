// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"net"

	"go.cryptoscope.co/luigi"
)

// Endpoint allows calling functions on the RPC peer.
//go:generate counterfeiter -o mock/endpoint.go . Endpoint
type Endpoint interface {
	// The different call types:
	Async(ctx context.Context, tipe interface{}, method Method, args ...interface{}) (interface{}, error)
	Source(ctx context.Context, tipe interface{}, method Method, args ...interface{}) (luigi.Source, error)
	Sink(ctx context.Context, method Method, args ...interface{}) (luigi.Sink, error)
	Duplex(ctx context.Context, tipe interface{}, method Method, args ...interface{}) (luigi.Source, luigi.Sink, error)

	// Do allows general calls
	Do(ctx context.Context, req *Request) error

	// Terminate wraps up the RPC session
	Terminate() error

	// Remote returns the network address of the remote
	Remote() net.Addr
}
