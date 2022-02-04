// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"fmt"
	"net"
	"os"
	"sync"
	"time"

	"github.com/libp2p/go-reuseport"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	"go.cryptoscope.co/ssb"
	multiserver "go.mindeco.de/ssb-multiserver"
)

type Discoverer struct {
	local ssb.KeyPair // to ignore our own

	rx4 net.PacketConn
	rx6 net.PacketConn

	brLock    sync.Mutex
	brodcasts map[int]chan net.Addr
}

func NewDiscoverer(local ssb.KeyPair) (*Discoverer, error) {
	d := &Discoverer{
		local:     local,
		brodcasts: make(map[int]chan net.Addr),
	}
	return d, d.start()
}

func (d *Discoverer) start() error {

	var err error
	d.rx4, err = makePktConn("udp4")
	if err != nil {
		return err
	}

	d.rx6, err = makePktConn("udp6")
	if err != nil {
		return err
	}

	go d.work(d.rx4)
	go d.work(d.rx6)

	return nil
}

func makePktConn(n string) (net.PacketConn, error) {
	lis, err := reuseport.ListenPacket(n, fmt.Sprintf(":%d", DefaultPort))
	if err != nil {
		return nil, fmt.Errorf("ssb: adv start failed to listen on v4 broadcast: %w", err)
	}
	switch v := lis.(type) {
	case *net.UDPConn:
		return v, nil
	default:
		return nil, fmt.Errorf("node Advertise: invalid rx listen type: %T", lis)
	}
}

func (d *Discoverer) work(rx net.PacketConn) {

	for {
		rx.SetReadDeadline(time.Now().Add(time.Second * 1))
		buf := make([]byte, 128)
		n, addr, err := rx.ReadFrom(buf)
		if err != nil {
			if !os.IsTimeout(err) {
				// log.Printf("rx adv err, breaking (%s)", err.Error())
				break
			}
			continue
		}

		buf = buf[:n] // strip of zero bytes
		// log.Printf("dbg adv raw: %q", string(buf))
		na, err := multiserver.ParseNetAddress(buf)
		if err != nil {
			// log.Println("rx adv err", err.Error())
			// TODO: _could_ try to get key out if just ws://[::]~shs:... and dial pkt origin
			continue
		}

		if na.Ref.Equal(d.local.ID()) {
			continue
		}

		ua := addr.(*net.UDPAddr)

		// skip advertisments not from source
		if !ua.IP.Equal(na.Addr.IP) {
			continue
		}

		na.Addr.Zone = ua.Zone

		// fmt.Printf("[localadv debug] %s (claimed:%s) %s\n", addr.String(), na.Addr.String(), na.Ref.Ref())

		wrappedAddr := netwrap.WrapAddr(&na.Addr, secretstream.Addr{PubKey: na.Ref.PubKey()})

		d.brLock.Lock()
		for _, ch := range d.brodcasts {
			ch <- wrappedAddr
		}
		d.brLock.Unlock()
	}
}

func (d *Discoverer) Stop() {
	d.brLock.Lock()
	for i, ch := range d.brodcasts {
		close(ch)
		delete(d.brodcasts, i)
	}
	if d.rx4 != nil {
		d.rx4.Close()
		d.rx4 = nil
	}
	if d.rx6 != nil {
		d.rx6.Close()
		d.rx6 = nil
	}
	d.brLock.Unlock()
	return
}

func (d *Discoverer) Notify() (<-chan net.Addr, func()) {
	ch := make(chan net.Addr)
	d.brLock.Lock()
	i := len(d.brodcasts)
	d.brodcasts[i] = ch
	d.brLock.Unlock()
	return ch, func() {
		d.brLock.Lock()
		_, open := d.brodcasts[i]
		if open {
			close(ch)
			delete(d.brodcasts, i)
		}
		d.brLock.Unlock()
	}
}
