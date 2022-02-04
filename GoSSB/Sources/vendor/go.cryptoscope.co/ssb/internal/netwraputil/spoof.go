// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package netwraputil

import (
	"errors"
	"net"

	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
)

// SpoofRemoteAddress wraps the connection with the passed reference
// as if it was a secret-handshake connection
// warning: should only be used where auth is established otherwise,
// like for testing or local client access over unixsock
func SpoofRemoteAddress(pubKey []byte) netwrap.ConnWrapper {
	if len(pubKey) != 32 {
		return func(_ net.Conn) (net.Conn, error) {
			return nil, errors.New("invalid public key length")
		}
	}
	var spoofedAddr secretstream.Addr
	spoofedAddr.PubKey = pubKey
	return func(c net.Conn) (net.Conn, error) {
		sc := SpoofedConn{
			Conn:          c,
			spoofedRemote: netwrap.WrapAddr(c.RemoteAddr(), spoofedAddr),
		}
		return sc, nil
	}
}

type SpoofedConn struct {
	net.Conn

	spoofedRemote net.Addr
}

func (sc SpoofedConn) RemoteAddr() net.Addr {
	return sc.spoofedRemote
}
