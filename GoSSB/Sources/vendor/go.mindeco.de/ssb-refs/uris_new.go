package refs

import (
	"encoding/base64"
	"fmt"
	"net"
	"net/url"

	"golang.org/x/crypto/ed25519"
)

type URIOption func(e *ExperimentalURI) error

func MSAddr(hostAndPort string, pubKey ed25519.PublicKey) URIOption {
	return func(e *ExperimentalURI) error {

		host, port, err := net.SplitHostPort(hostAndPort)
		if err != nil {
			return err
		}

		// cant import go.mindeco.de/ssb-multiserver
		msAddr := fmt.Sprintf("net:%s:%s~shs:%s", host, port, base64.StdEncoding.EncodeToString(pubKey))
		e.params.Set("msaddr", msAddr)
		e.params.Set("action", "add-pub")
		return nil
	}
}

func RoomInvite(code string) URIOption {
	return func(e *ExperimentalURI) error {
		e.params.Set("invite", code)
		e.params.Set("action", "join-room")
		return nil
	}
}

func RoomAlias(roomID, userID, alias, signature string) URIOption {
	return func(e *ExperimentalURI) error {
		e.params.Set("roomID", roomID)
		e.params.Set("userID", userID)
		e.params.Set("action", "consume-alias")
		return nil
	}
}

func NewExperimentalURI(opts ...URIOption) (*url.URL, error) {
	var e ExperimentalURI

	e.params = make(url.Values)

	for i, opt := range opts {
		err := opt(&e)
		if err != nil {
			return nil, fmt.Errorf("NewExperimentalURI: option %d failed: %w", i, err)
		}
	}

	var u url.URL
	u.Scheme = "ssb"
	u.RawQuery = e.params.Encode()
	u.Opaque = "experimental"

	return &u, nil
}
