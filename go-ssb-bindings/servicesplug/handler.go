package servicesplug

import (
	"context"
	"time"

	"github.com/cryptix/go/encodedTime"

	"go.cryptoscope.co/ssb"

	"go.cryptoscope.co/muxrpc/v2"
)

type Token struct {
	Token   string                `json:"token"`
	Expires encodedTime.Millisecs `json:"expires"`
}

func (t Token) Expired() bool {
	if t.Token == "" {
		return true
	}
	te := time.Time(t.Expires)
	return time.Now().After(te)
}

func (p *Plugin) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {
	p.cl.Lock()
	defer p.cl.Unlock()
	if !p.currentToken.Expired() {
		return
	}

	remoteRef, err := ssb.GetFeedRefFromAddr(e.Remote())
	if err != nil {
		return
	}

	if _, ok := p.trusted[refAsArray(remoteRef)]; !ok {
		return
	}

	var tok Token

	err = e.Async(ctx, &tok, muxrpc.TypeBinary, muxrpc.Method{"planetary", "getToken"})
	if err != nil {
		return
	}

	p.currentToken = tok
	p.notify(tok)
}

func (p *Plugin) HandleCall(ctx context.Context, req *muxrpc.Request) {}

func (p Plugin) Handled(method muxrpc.Method) bool {
	return true
}
