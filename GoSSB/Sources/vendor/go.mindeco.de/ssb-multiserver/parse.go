// SPDX-License-Identifier: MIT

// first draft of an (surely) incomlete implemenation of multiserver addresses
package multiserver

import (
	"bytes"
	"encoding/base64"
	"net"
	"strconv"
	"strings"

	"github.com/pkg/errors"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	refs "go.mindeco.de/ssb-refs"
)

var (
	ErrNoNetAddr = errors.New("multiserver: no net~shs combination")
	ErrNoSHSKey  = errors.New("multiserver: no or invalid shs1 key")
)

type NetAddress struct {
	Addr net.TCPAddr
	Ref  refs.FeedRef
}

func (na NetAddress) String() string {
	var sb strings.Builder
	sb.WriteString("net:")
	sb.WriteString(na.Addr.String())
	sb.WriteString("~shs:")
	sb.WriteString(base64.StdEncoding.EncodeToString(na.Ref.PubKey()))
	return sb.String()
}

// WrappedAddr returns a netwrap'ed address that can be dialed easily using secretstream
func (na NetAddress) WrappedAddr() net.Addr {
	return netwrap.WrapAddr(&na.Addr, secretstream.Addr{PubKey: na.Ref.PubKey()})
}

func ParseNetAddress(input []byte) (*NetAddress, error) {
	var na NetAddress
	for _, p := range bytes.Split(input, []byte{';'}) {
		netPrefix := []byte("net:")
		if bytes.HasPrefix(p, netPrefix) {

			// where does the pubkey reside in this
			keyStart := bytes.Index(p, []byte("~shs:"))
			if keyStart == -1 {
				return nil, ErrNoSHSKey
			}

			netPart := p[len(netPrefix):keyStart]
			shsPart := p[keyStart+5:]

			// port and address handling
			host, portStr, err := net.SplitHostPort(string(netPart))
			if err != nil {
				return nil, errors.Wrap(ErrNoNetAddr, "multiserver: no valid Host + Port combination")
			}
			na.Addr.IP = net.ParseIP(host)
			if na.Addr.IP == nil {
				ipAddr, err := net.ResolveIPAddr("ip", host)
				if err != nil {
					return nil, errors.Wrap(ErrNoNetAddr, "multiserver: failed to fallback to resolving addr")
				}
				na.Addr.IP = ipAddr.IP
			}
			port, err := strconv.Atoi(portStr)
			if err != nil {
				return nil, errors.Wrap(ErrNoNetAddr, "multiserver: badly formatted port")
			}
			na.Addr.Port = port

			var keyBuf = make([]byte, 35)
			n, err := base64.StdEncoding.Decode(keyBuf, shsPart)
			if err != nil {
				return nil, errors.Wrapf(ErrNoSHSKey, "multiserver: invalid pubkey formatting: %s", err)
			}
			if n != 32 {
				return nil, errors.Wrap(ErrNoSHSKey, "multiserver: pubkey not 32bytes long")
			}

			na.Ref, err = refs.NewFeedRefFromBytes(keyBuf[:32], refs.RefAlgoFeedSSB1)
			return &na, err
		}
	}
	return nil, ErrNoNetAddr
}
