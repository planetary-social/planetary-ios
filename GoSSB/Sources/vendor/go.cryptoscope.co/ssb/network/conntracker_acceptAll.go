// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"context"
	"net"
	"sync"
	"time"

	"go.cryptoscope.co/ssb"
)

// This just keeps a count and doesn't actually track anything
func NewAcceptAllTracker() ssb.ConnTracker {
	return &acceptAllTracker{}
}

type acceptAllTracker struct {
	countLock sync.Mutex
	conns     []net.Conn
}

func (ct *acceptAllTracker) CloseAll() {
	ct.countLock.Lock()
	defer ct.countLock.Unlock()
	for _, c := range ct.conns {
		c.Close()
	}
	ct.conns = []net.Conn{}
}

func (ct *acceptAllTracker) Count() uint {
	ct.countLock.Lock()
	defer ct.countLock.Unlock()
	return uint(len(ct.conns))
}

func (ct *acceptAllTracker) Active(a net.Addr) (bool, time.Duration) {
	ct.countLock.Lock()
	defer ct.countLock.Unlock()
	for _, c := range ct.conns {
		if sameByRemote(c, a) {
			return true, 0
		}
	}
	return false, 0
}

func (ct *acceptAllTracker) OnAccept(ctx context.Context, conn net.Conn) (bool, context.Context) {
	ct.countLock.Lock()
	defer ct.countLock.Unlock()
	ct.conns = append(ct.conns, conn)
	return true, ctx
}

func (ct *acceptAllTracker) OnClose(conn net.Conn) time.Duration {
	ct.countLock.Lock()
	defer ct.countLock.Unlock()
	for i, c := range ct.conns {

		if sameByRemote(c, conn.RemoteAddr()) {
			// remove from array, replace style
			ct.conns[i] = ct.conns[len(ct.conns)-1]
			ct.conns[len(ct.conns)-1] = nil
			ct.conns = ct.conns[:len(ct.conns)-1]
			return 1
		}

	}

	return 0
}

func sameByRemote(a net.Conn, b net.Addr) bool {
	return a.RemoteAddr().String() == b.String()
}
