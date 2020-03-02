// SPDX-License-Identifier: MIT

package network

import (
	"encoding/base64"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"time"

	"github.com/libp2p/go-reuseport"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
	multiserver "go.mindeco.de/ssb-multiserver"
)

type Advertiser struct {
	keyPair *ssb.KeyPair

	local  *net.UDPAddr // Local listening address, may not be needed (auto-detect?).
	remote *net.UDPAddr // Address being broadcasted to, this should be deduced form 'local'.

	waitTime time.Duration
	ticker   *time.Ticker
}

func newPublicKeyString(keyPair *ssb.KeyPair) string {
	publicKey := keyPair.Pair.Public[:]
	return base64.StdEncoding.EncodeToString(publicKey)
}

func newAdvertisement(local *net.UDPAddr, keyPair *ssb.KeyPair) (string, error) {
	if local == nil {
		return "", errors.Errorf("ssb: passed nil local address")
	}

	withoutZone := *local
	withoutZone.Zone = ""

	// crunchy way of making a https://github.com/ssbc/multiserver/
	msg := fmt.Sprintf("net:%s~shs:%s", &withoutZone, newPublicKeyString(keyPair))
	_, err := multiserver.ParseNetAddress([]byte(msg))
	return msg, err
}

func NewAdvertiser(local net.Addr, keyPair *ssb.KeyPair) (*Advertiser, error) {

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
		return nil, errors.Errorf("node Advertise: invalid local address type: %T", local)
	}
	log.Printf("adverstiser using local address %s", udpAddr)

	remote, err := net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", net.IPv4bcast, DefaultPort))
	if err != nil {
		return nil, errors.Wrap(err, "ssb/NewAdvertiser: failed to resolve v4 broadcast addr")
	}

	return &Advertiser{
		local:    udpAddr,
		remote:   remote,
		waitTime: time.Second * 45,
		keyPair:  keyPair,
	}, nil
}

func (b *Advertiser) advertise() error {
	localAddresses, err := findSiteLocalNetworkAddresses(b.local)
	if err != nil {
		return errors.Wrap(err, "ssb: failed to make new advertisment")
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
			return errors.Errorf("cannot get Port for network type %s", localAddress.Network())
		}

		broadcastAddress, err := localBroadcastAddress(localAddress)
		if err != nil {
			return errors.Wrap(err, "ssb: failed to find site local address broadcast address")
		}
		dstStr := net.JoinHostPort(broadcastAddress, strconv.Itoa(DefaultPort))
		remoteUDP, err := net.ResolveUDPAddr("udp", dstStr)
		if err != nil {
			return errors.Wrapf(err, "ssb: failed to resolve broadcast dest addr for advertiser: %s", dstStr)
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
			// err = errors.Wrapf(err, "adv send of msg failed")
			// log.Println("debug,cont:", err)
			continue
		}
		_ = broadcastConn.Close()
		if err != nil {
			// err = errors.Wrapf(err, "close of con failed")
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
