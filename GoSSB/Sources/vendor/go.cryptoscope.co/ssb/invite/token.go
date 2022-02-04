// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package invite

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"

	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	refs "go.mindeco.de/ssb-refs"
)

var ErrInvalidToken = errors.New("invite: invalid token")

type Token struct {
	Peer    refs.FeedRef
	Address net.Addr

	Seed [32]byte
}

func (c Token) String() string {
	addr := netwrap.GetAddr(c.Address, "tcp")
	if addr == nil {
		return "invalid:no tcp address"
	}

	shsAddr := netwrap.GetAddr(c.Address, secretstream.NetworkString)
	if shsAddr == nil {
		return "invalid:no secret-handshake address"
	}

	var s strings.Builder
	s.WriteString(addr.String())
	s.WriteString(":")
	s.WriteString(c.Peer.String())
	s.WriteString("~")
	s.WriteString(base64.StdEncoding.EncodeToString(c.Seed[:]))
	return s.String()
}

func NewPubMessageFromToken(tok Token) (*refs.OldPubMessage, error) {
	addr := netwrap.GetAddr(tok.Address, "tcp")
	if addr == nil {
		return nil, errors.New("invalid invite token - no tcp address")
	}

	tcpAddr, ok := addr.(*net.TCPAddr)
	if !ok {
		return nil, fmt.Errorf("invalid invite token - wrong address type: %T", addr)
	}

	return &refs.OldPubMessage{
		Type: "pub",
		Address: refs.OldAddress{
			Key:  tok.Peer,
			Host: tcpAddr.IP.String(),
			Port: tcpAddr.Port,
		},
	}, nil
}

// ParseLegacyToken takes an legacy invite token of the form
// host:port:@feed.Ref~base64Seed
func ParseLegacyToken(input string) (Token, error) {
	var c Token

	split := strings.Split(input, ":")
	if len(split) != 3 {
		if input[0] != '[' {
			return Token{}, ErrInvalidToken
		}

		ipv6End := strings.IndexRune(input, ']')
		if ipv6End == -1 {
			return Token{}, ErrInvalidToken
		}

		split[0] = input[1:ipv6End]

		portStart := ipv6End + 1
		if input[portStart] != ':' {
			return Token{}, ErrInvalidToken
		}
		portStart++

		portEnd := strings.Index(input[portStart:], ":")
		if portEnd == -1 {
			return Token{}, ErrInvalidToken
		}
		portEnd += portStart

		split[1] = input[portStart:portEnd]
		split[2] = input[portEnd+1:]
	}

	if !strings.HasPrefix(split[2], "@") {
		return Token{}, ErrInvalidToken
	}

	refAndSeed := strings.Split(split[2], "~")
	if len(refAndSeed) != 2 {
		return Token{}, ErrInvalidToken
	}

	var err error
	ref, err := refs.ParseFeedRef(refAndSeed[0])
	if err != nil {
		return Token{}, err
	}
	c.Peer = ref

	seed, err := base64.StdEncoding.DecodeString(refAndSeed[1])
	if err != nil {
		return Token{}, err
	}
	if len(seed) != 32 {
		return Token{}, ErrInvalidToken
	}
	copy(c.Seed[:], seed)

	tcpAddr := net.TCPAddr{}
	tcpAddr.IP = net.ParseIP(split[0])
	if tcpAddr.IP == nil {
		resolvedAddr, err := net.ResolveIPAddr("ip", split[0])
		if err != nil {
			// could be tor or other kind of overlay?
			return Token{}, err
		}
		tcpAddr.IP = resolvedAddr.IP
	}
	tcpAddr.Port, err = strconv.Atoi(split[1])
	if err != nil {
		return Token{}, err
	}

	c.Address = netwrap.WrapAddr(&tcpAddr, secretstream.Addr{PubKey: ref.PubKey()})

	return c, nil
}
