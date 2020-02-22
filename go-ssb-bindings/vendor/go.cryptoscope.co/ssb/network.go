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
	Closed() bool
}

type ConnTracker interface {
	Active(net.Addr) (bool, time.Duration)
	OnAccept(conn net.Conn) bool
	OnClose(conn net.Conn) time.Duration
	Count() uint
	CloseAll()
}
