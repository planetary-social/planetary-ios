// SPDX-License-Identifier: MIT

package secretstream // import "go.cryptoscope.co/secretstream"

import (
	"fmt"
	"net"
	"time"

	"go.cryptoscope.co/secretstream/boxstream"
	"go.cryptoscope.co/secretstream/secrethandshake"

	"go.cryptoscope.co/netwrap"
)

// Client can dial secret-handshake server endpoints
type Client struct {
	appKey []byte
	kp     secrethandshake.EdKeyPair
}

// NewClient creates a new Client with the passed keyPair and appKey
func NewClient(kp secrethandshake.EdKeyPair, appKey []byte) (*Client, error) {
	// TODO: consistancy check?!..
	return &Client{
		appKey: appKey,
		kp:     kp,
	}, nil
}

// ConnWrapper returns a connection wrapper for the client.
func (c *Client) ConnWrapper(pubKey []byte) netwrap.ConnWrapper {
	return func(conn net.Conn) (net.Conn, error) {
		state, err := secrethandshake.NewClientState(c.appKey, c.kp, pubKey)
		if err != nil {
			return nil, err
		}

		errc := make(chan error)
		go func() {
			errc <- secrethandshake.Client(state, conn)
			close(errc)
		}()

		select {
		case err := <-errc:
			if err != nil {
				return nil, err
			}
		case <-time.After(30 * time.Second):
			return nil, fmt.Errorf("secretstream: handshake timeout")
		}

		enKey, enNonce := state.GetBoxstreamEncKeys()
		deKey, deNonce := state.GetBoxstreamDecKeys()

		boxed := &Conn{
			boxer:   boxstream.NewBoxer(conn, &enNonce, &enKey),
			unboxer: boxstream.NewUnboxer(conn, &deNonce, &deKey),
			conn:    conn,
			local:   c.kp.Public[:],
			remote:  state.Remote(),
		}

		return boxed, nil
	}
}
