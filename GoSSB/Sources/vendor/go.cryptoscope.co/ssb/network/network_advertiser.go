// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"time"

	"github.com/libp2p/go-reuseport"
	"golang.org/x/crypto/ed25519"

	"go.cryptoscope.co/ssb"
	multiserver "go.mindeco.de/ssb-multiserver"
)

type Advertiser struct {
	keyPair ssb.KeyPair

	local  *net.UDPAddr // Local listening address, may not be needed (auto-detect?).
	remote *net.UDPAddr // Address being broadcasted to, this should be deduced form 'local'.

	waitTime time.Duration
	ticker   *time.Ticker
}

func newPublicKeyString(publicKey ed25519.PublicKey) string {
	return base64.StdEncoding.EncodeToString(publicKey)
}

func newAdvertisement(local *net.UDPAddr, keyPair ssb.KeyPair) (string, error) {
	if local == nil {
		return "", errors.New("ssb: passed nil local address")
	}

	withoutZone := *local
	withoutZone.Zone = ""

	// crunchy way of making a https://github.com/ssbc/multiserver/
	msg := fmt.Sprintf("net:%s~shs:%s", &withoutZone, newPublicKeyString(keyPair.ID().PubKey()))
	_, err := multiserver.ParseNetAddress([]byte(msg))
	return msg, err
}

func NewAdvertiser(local net.Addr, keyPair ssb.KeyPair) (*Advertiser, error) {

	var udpAddr *net.UDPAddr
	switch nv := local.(type) {
	case *net.TCPAddr:
		udpAddr = new(net.UDPAddr)
		udpAddr.IP = nv.IP
		udpAddr.Port = nv.Port
		if !isIPv4(nv.IP) {
			udpAddr.Zone = nv.Zone
		}
	case *net.UDPAddr:
		udpAddr = nv
	default:
		return nil, fmt.Errorf("node Advertise: invalid local address type: %T", local)
	}
	log.Printf("adverstiser using local address %s", udpAddr)

	remote, err := net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", net.IPv4bcast, DefaultPort))
	if err != nil {
		return nil, fmt.Errorf("ssb/NewAdvertiser: failed to resolve v4 broadcast addr: %w", err)
	}

	return &Advertiser{
		local:    udpAddr,
		remote:   remote,
		waitTime: time.Second * 15,
		keyPair:  keyPair,
	}, nil
}

func (b *Advertiser) advertise() error {
	localAddresses, err := findSiteLocalNetworkAddresses(b.local)
	if err != nil {
		return fmt.Errorf("ssb: failed to make new advertisment: %w", err)
	}

	for _, localAddress := range localAddresses {
		// log.Print("DBG23: using", localAddress)
		var localUDP = new(net.UDPAddr)
		// carry port from address or use default one
		switch v := localAddress.(type) {
		case *net.IPAddr:
			localUDP.IP = v.IP
			if !isIPv4(v.IP) {
				localUDP.Zone = v.Zone
			}
			localUDP.Port = DefaultPort
		case *net.IPNet:
			localUDP.IP = v.IP
			localUDP.Port = DefaultPort
		case *net.TCPAddr:
			localUDP.IP = v.IP
			localUDP.Port = v.Port
		case *net.UDPAddr:
			localUDP.IP = v.IP
			localUDP.Port = v.Port
		default:
			return fmt.Errorf("cannot get Port for network type %s", localAddress.Network())
		}

		broadcastAddress, err := localBroadcastAddress(localAddress)
		if err != nil {
			return fmt.Errorf("ssb: failed to find site local address broadcast address: %w", err)
		}
		dstStr := net.JoinHostPort(broadcastAddress, strconv.Itoa(DefaultPort))
		remoteUDP, err := net.ResolveUDPAddr("udp", dstStr)
		if err != nil {
			return fmt.Errorf("ssb: failed to resolve broadcast dest addr for advertiser: %s: %w", dstStr, err)
		}

		msg, err := newAdvertisement(
			localUDP,
			b.keyPair,
		)
		if err != nil {
			return err
		}
		broadcastConn, err := reuseport.Dial("udp", localUDP.String(), remoteUDP.String())
		if err != nil {
			// err = errors.Wrap(err, "adv dial failed")
			// log.Println("debug,cont:", err)
			continue
		}
		_, err = fmt.Fprint(broadcastConn, msg)
		if err != nil {
			// err = fmt.Errorf("adv send of msg failed",err)
			// log.Println("debug,cont:", err)
			continue
		}
		_ = broadcastConn.Close()
		if err != nil {
			// err = fmt.Errorf("close of con failed",err)
			// log.Println("debug,cont:", err)
			continue
		}
		// log.Println("adv pkt sent:", msg)
	}
	return nil
}

func (b *Advertiser) Start() {
	b.ticker = time.NewTicker(b.waitTime)
	// TODO: notice interface changes
	// net.IPv6linklocalallnodes

	go func() {
		for range b.ticker.C {
			err := b.advertise()
			if err != nil {
				if !os.IsTimeout(err) {
					// TODO debug leveled logging
					// log.Printf("tx adv err (%s)", err.Error())
				}
			}
		}
	}()
}

func (b *Advertiser) Stop() {
	if b.ticker != nil {
		b.ticker.Stop()
	}
}
