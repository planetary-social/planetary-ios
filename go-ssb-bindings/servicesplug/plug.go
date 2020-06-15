// Package servicesplug defines the client side portion of the custom muxrpc plugins for planetary.
// It's main function is to request a bearer token that can be used for other HTTP based services.
package servicesplug

import (
	"fmt"
	"sync"

	"golang.org/x/crypto/ed25519"

	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
)

const pubKeySize = ed25519.PublicKeySize

type pubKey [pubKeySize]byte

func refAsArray(fr ssb.FeedRef) pubKey {
	var k pubKey
	if n := copy(k[:], fr.PubKey()); n != pubKeySize {
		panic(fmt.Sprintf("invalid public key size:%d", n))
	}
	return k
}

type trustedPeerMap map[pubKey]struct{}

type Plugin struct {
	trusted trustedPeerMap

	cl           *sync.Mutex
	currentToken Token
}

var _ ssb.Plugin = (*Plugin)(nil)

func New(pubs []ssb.FeedRef) *Plugin {
	p := Plugin{
		cl: &sync.Mutex{},

		trusted: make(trustedPeerMap, len(pubs)),
	}
	for _, pub := range pubs {
		p.trusted[refAsArray(pub)] = struct{}{} // TODO: move to pubkey
	}
	return &p
}

func (Plugin) Name() string               { return "planetary" }
func (Plugin) Method() muxrpc.Method      { return muxrpc.Method{"planetary"} }
func (p *Plugin) Handler() muxrpc.Handler { return p }

func (p *Plugin) HasValidToken() (string, bool) {
	p.cl.Lock()
	defer p.cl.Unlock()
	if p.currentToken.Expired() {
		return "", false
	}
	return p.currentToken.Token, true
}
