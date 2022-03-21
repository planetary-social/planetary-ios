// SPDX-License-Identifier: MIT

package secretstream

import (
	"bytes"
	"encoding/base64"
	"errors"
	"net"
	"os"
	"syscall"
	"time"

	"go.cryptoscope.co/secretstream/boxstream"

	"go.cryptoscope.co/netwrap"
)

const NetworkString = "shs-bs"

// Addr wrapps a net.Addr and adds the public key
type Addr struct {
	PubKey []byte
}

// Network returns NetworkString, the network id of this protocol.
// Can be used with go.cryptoscope.co/netwrap to wrap the underlying connection.
func (a Addr) Network() string {
	return NetworkString
}

func (a Addr) String() string {
	// TODO keks: is this the address format we want to use?
	return "@" + base64.StdEncoding.EncodeToString(a.PubKey) + ".ed25519"
}

// Conn is a boxstream wrapped net.Conn
type Conn struct {
	conn net.Conn

	boxer   *boxstream.Boxer
	unboxer *boxstream.Unboxer
	recvMsg []byte // last message read from unboxer

	// public keys
	local, remote []byte
}

// Read implements io.Reader.
func (conn *Conn) Read(p []byte) (int, error) {
	if len(conn.recvMsg) == 0 {
		msg, err := conn.unboxer.ReadMessage()
		if err != nil {
			return 0, err
		}
		conn.recvMsg = msg
	}
	n := copy(p, conn.recvMsg)
	conn.recvMsg = conn.recvMsg[n:]
	return n, nil
}

// Write implements io.Writer.
func (conn *Conn) Write(p []byte) (int, error) {
	for buf := bytes.NewBuffer(p); buf.Len() > 0; {
		if err := conn.boxer.WriteMessage(buf.Next(boxstream.MaxSegmentSize)); err != nil {
			return 0, err
		}
	}
	return len(p), nil
}

// Close closes the underlying net.Conn
func (conn *Conn) Close() error {
	gerr := conn.boxer.WriteGoodbye()
	if gerr != nil {
		netErr := new(net.OpError)
		if errors.As(gerr, &netErr) {
			var sysCallErr = new(os.SyscallError)
			if errors.As(netErr.Err, &sysCallErr) {
				action := sysCallErr.Unwrap()
				if action == syscall.ECONNRESET || action == syscall.EPIPE {
					return nil
				}
			}
			if netErr.Err.Error() == "use of closed network connection" {
				return nil
			}
		}
		return gerr
	}

	if cerr := conn.conn.Close(); cerr != nil {
		return cerr
	}

	return nil
}

// LocalAddr returns the local net.Addr with the local public key
func (conn *Conn) LocalAddr() net.Addr {
	return netwrap.WrapAddr(conn.conn.LocalAddr(), Addr{conn.local})
}

// RemoteAddr returns the remote net.Addr with the remote public key
func (conn *Conn) RemoteAddr() net.Addr {
	return netwrap.WrapAddr(conn.conn.RemoteAddr(), Addr{conn.remote})
}

// SetDeadline passes the call to the underlying net.Conn
func (conn *Conn) SetDeadline(t time.Time) error {
	return conn.conn.SetDeadline(t)
}

// SetReadDeadline passes the call to the underlying net.Conn
func (conn *Conn) SetReadDeadline(t time.Time) error {
	return conn.conn.SetReadDeadline(t)
}

// SetWriteDeadline passes the call to the underlying net.Conn
func (conn *Conn) SetWriteDeadline(t time.Time) error {
	return conn.conn.SetWriteDeadline(t)
}
