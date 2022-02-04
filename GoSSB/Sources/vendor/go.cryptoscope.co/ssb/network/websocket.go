// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log/level"
)

func websockHandler(n *Node) http.HandlerFunc {
	var upgrader = websocket.Upgrader{
		ReadBufferSize:  1024 * 4,
		WriteBufferSize: 1024 * 4,
		CheckOrigin: func(_ *http.Request) bool {
			return true
		},
		EnableCompression: false,
	}
	return func(w http.ResponseWriter, req *http.Request) {
		remoteAddr, err := net.ResolveTCPAddr("tcp", req.RemoteAddr)
		if err != nil {
			n.log.Log("warning", "failed wrap", "err", err, "remote", remoteAddr)
			return
		}
		wsConn, err := upgrader.Upgrade(w, req, nil)
		if err != nil {
			n.log.Log("warning", "failed wrap", "err", err, "remote", remoteAddr)
			return
		}

		var wc net.Conn
		wc = &wrappedConn{
			remote: remoteAddr,
			local: &net.TCPAddr{
				IP:   nil,
				Port: 8989,
			},
			wsc: wsConn,
		}

		// comment out this block to get `noauth` instead of `shs`
		// TODO:
		// netwrap.WrapAddr(remoteAddr, secretstream.Addr{
		// 	PubKey: n.opts.KeyPair.ID().ID,
		// })
		cw := n.secretServer.ConnWrapper()
		wc, err = cw(wc)
		if err != nil {
			level.Error(n.log).Log("warning", "failed to crypt", "err", err, "remote", remoteAddr)
			wsConn.Close()
			return
		}

		// debugging copy of all muxrpc frames
		// can be handy for reversing applications
		// wrapped, err := debug.WrapDump("webmux", cryptoConn)
		// if err != nil {
		// 	level.Error(n.log).Log("warning", "failed wrap", "err", err, "remote", remoteAddr)
		// 	wsConn.Close()
		// 	return
		// }

		pkr := muxrpc.NewPacker(wc)

		h, err := n.opts.MakeHandler(wc)
		if err != nil {
			err = fmt.Errorf("unix sock make handler: %w", err)
			level.Error(n.log).Log("warn", err)
			wsConn.Close()
			return
		}

		edp := muxrpc.Handle(pkr, h,
			muxrpc.WithContext(req.Context()),
			muxrpc.WithRemoteAddr(wc.RemoteAddr()))

		srv := edp.(muxrpc.Server)
		// TODO: bundle root and connection context
		if err := srv.Serve(); err != nil {
			level.Error(n.log).Log("conn", "serve exited", "err", err, "peer", remoteAddr)
		}
		wsConn.Close()
	}
}

type wrappedConn struct {
	remote net.Addr
	local  net.Addr

	r   io.Reader
	wsc *websocket.Conn
}

func (conn *wrappedConn) Read(data []byte) (int, error) {
	if conn.r == nil {
		if err := conn.renewReader(); err != nil {
			return -1, err
		}

	}
	n, err := conn.r.Read(data)
	if err == io.EOF {
		if err := conn.renewReader(); err != nil {
			return -1, err
		}
		return conn.Read(data)
	}

	return n, err
}

func (wc *wrappedConn) renewReader() error {
	mt, r, err := wc.wsc.NextReader()
	if err != nil {
		return fmt.Errorf("wsConn: failed to get reader: %w", err)
	}

	if mt != websocket.BinaryMessage {
		return fmt.Errorf("wsConn: not binary message: %v", mt)

	}
	wc.r = r
	return nil
}

func (conn wrappedConn) Write(data []byte) (int, error) {
	writeCloser, err := conn.wsc.NextWriter(websocket.BinaryMessage)
	if err != nil {
		return -1, fmt.Errorf("wsConn: failed to create Reader: %w", err)
	}

	n, err := io.Copy(writeCloser, bytes.NewReader(data))
	if err != nil {
		return -1, fmt.Errorf("wsConn: failed to copy data: %w", err)
	}
	return int(n), writeCloser.Close()
}

func (conn wrappedConn) Close() error {
	return conn.wsc.Close()
}

func (c wrappedConn) LocalAddr() net.Addr  { return c.local }
func (c wrappedConn) RemoteAddr() net.Addr { return c.remote }
func (c wrappedConn) SetDeadline(t time.Time) error {
	return nil // c.conn.SetDeadline(t)
}
func (c wrappedConn) SetReadDeadline(t time.Time) error {
	return nil // c.conn.SetReadDeadline(t)
}
func (c wrappedConn) SetWriteDeadline(t time.Time) error {
	return nil // c.conn.SetWriteDeadline(t)
}
