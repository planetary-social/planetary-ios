// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"context"
	"log"
	"net"
	"sync"
	"time"

	"github.com/go-kit/kit/metrics"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	"go.cryptoscope.co/ssb"
)

type instrumentedConnTracker struct {
	root ssb.ConnTracker

	count     metrics.Gauge
	durration metrics.Histogram
}

func NewInstrumentedConnTracker(r ssb.ConnTracker, ct metrics.Gauge, h metrics.Histogram) ssb.ConnTracker {
	i := instrumentedConnTracker{root: r, count: ct, durration: h}
	return &i
}

func (ict instrumentedConnTracker) Count() uint {
	n := ict.root.Count()
	ict.count.With("part", "tracked_count").Set(float64(n))
	return n
}

func (ict instrumentedConnTracker) CloseAll() {
	ict.root.CloseAll()
}

func (ict instrumentedConnTracker) Active(a net.Addr) (bool, time.Duration) {
	return ict.root.Active(a)
}

func (ict instrumentedConnTracker) OnAccept(ctx context.Context, conn net.Conn) (bool, context.Context) {
	ok, ctx := ict.root.OnAccept(ctx, conn)
	if ok {
		ict.count.With("part", "tracked_conns").Add(1)
	}
	return ok, ctx
}

func (ict instrumentedConnTracker) OnClose(conn net.Conn) time.Duration {
	durr := ict.root.OnClose(conn)
	if durr > 0 {
		ict.count.With("part", "tracked_conns").Add(-1)
		ict.durration.With("part", "tracked_conns").Observe(durr.Seconds())
	}
	return durr
}

type connEntry struct {
	c       net.Conn
	started time.Time
	done    chan struct{}
	cancel  context.CancelFunc
}

type connLookupMap map[[32]byte]connEntry

func toActive(a net.Addr) [32]byte {
	var pk [32]byte
	shs, ok := netwrap.GetAddr(a, "shs-bs").(secretstream.Addr)
	if !ok {
		panic("not an SHS connection")
	}
	copy(pk[:], shs.PubKey)
	return pk
}

func NewConnTracker() ssb.ConnTracker {
	return &connTracker{active: make(connLookupMap)}
}

// tracks open connections and refuses to established pubkeys
type connTracker struct {
	activeLock sync.Mutex
	active     connLookupMap
}

func (ct *connTracker) CloseAll() {
	ct.activeLock.Lock()
	defer ct.activeLock.Unlock()
	for k, c := range ct.active {
		if err := c.c.Close(); err != nil {
			log.Printf("failed to close %x: %v\n", k[:5], err)
		}
		c.cancel()
		// seems nice but we are holding the lock
		// <-c.done
		// delete(ct.active, k)
		// we must _trust_ the connection is hooked up to OnClose to remove it's entry
	}
}

func (ct *connTracker) Count() uint {
	ct.activeLock.Lock()
	defer ct.activeLock.Unlock()
	return uint(len(ct.active))
}

func (ct *connTracker) Active(a net.Addr) (bool, time.Duration) {
	ct.activeLock.Lock()
	defer ct.activeLock.Unlock()
	k := toActive(a)
	l, ok := ct.active[k]
	if !ok {
		return false, 0
	}
	return true, time.Since(l.started)
}

func (ct *connTracker) OnAccept(ctx context.Context, conn net.Conn) (bool, context.Context) {
	ct.activeLock.Lock()
	defer ct.activeLock.Unlock()
	k := toActive(conn.RemoteAddr())
	_, ok := ct.active[k]
	if ok {
		return false, nil
	}
	ctx, cancel := context.WithCancel(ctx)
	ct.active[k] = connEntry{
		c:       conn,
		started: time.Now(),
		done:    make(chan struct{}),
		cancel:  cancel,
	}
	return true, ctx
}

func (ct *connTracker) OnClose(conn net.Conn) time.Duration {
	ct.activeLock.Lock()
	defer ct.activeLock.Unlock()

	k := toActive(conn.RemoteAddr())
	who, ok := ct.active[k]
	if !ok {
		return 0
	}
	close(who.done)
	delete(ct.active, k)
	return time.Since(who.started)
}

// NewLastWinsTracker returns a conntracker that just kills the previous connection and let's the new one in.
func NewLastWinsTracker() ssb.ConnTracker {
	return &trackerLastWins{connTracker{active: make(connLookupMap)}}
}

type trackerLastWins struct {
	connTracker
}

func (ct *trackerLastWins) OnAccept(ctx context.Context, newConn net.Conn) (bool, context.Context) {
	ct.activeLock.Lock()
	k := toActive(newConn.RemoteAddr())
	oldConn, ok := ct.active[k]
	ct.activeLock.Unlock()
	if ok {
		oldConn.c.Close()
		oldConn.cancel()
		select {
		case <-oldConn.done:
			// cleaned up after itself
		case <-time.After(10 * time.Second):
			log.Println("[ConnTracker/lastWins] warning: not accepted, would ghost connection:", oldConn.c.RemoteAddr().String(), time.Since(oldConn.started))
			return false, nil
		}
	}
	ct.activeLock.Lock()
	ctx, cancel := context.WithCancel(ctx)
	ct.active[k] = connEntry{
		c:       newConn,
		started: time.Now(),
		done:    make(chan struct{}),
		cancel:  cancel,
	}
	ct.activeLock.Unlock()
	return true, ctx
}
