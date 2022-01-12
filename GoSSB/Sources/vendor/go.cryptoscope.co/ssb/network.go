// SPDX-License-Identifier: MIT

package ssb

import (
	"context"
	"io"
	"net"
	"time"

	"go.cryptoscope.co/muxrpc"
)

// EndpointStat gives some information about a connected peer
type EndpointStat struct {
	ID       *FeedRef
	Addr     net.Addr
	Since    time.Duration
	Endpoint muxrpc.Endpoint
}

type Network interface {
	Connect(ctx context.Context, addr net.Addr) error
	Serve(context.Context, ...muxrpc.HandlerWrapper) error
	GetListenAddr() net.Addr

	GetAllEndpoints() []EndpointStat
	GetEndpointFor(*FeedRef) (muxrpc.Endpoint, bool)

	GetConnTracker() ConnTracker

	io.Closer
}

// ConnTracker decides if connections should be established and keeps track of them
type ConnTracker interface {
	// Active returns true and since when a peer connection is active
	Active(net.Addr) (bool, time.Duration)

	// OnAccept receives a new connection as an argument.
	// If it decides to accept it, it returns true and a context that will be canceled once it should shut down
	// If it decides to deny it, it returns false (and a nil context)
	OnAccept(context.Context, net.Conn) (bool, context.Context)

	// OnClose notifies the tracker that a connection was closed
	OnClose(conn net.Conn) time.Duration

	// Count returns the number of open connections
	Count() uint

	// CloseAll closes all tracked connections
	CloseAll()
}
