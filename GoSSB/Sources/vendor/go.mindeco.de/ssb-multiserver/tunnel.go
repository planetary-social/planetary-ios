package multiserver

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"strings"

	"github.com/pkg/errors"
	refs "go.mindeco.de/ssb-refs"
)

type TunnelAddress struct {
	Intermediary refs.FeedRef
	Target       refs.FeedRef
}

func (ta TunnelAddress) String() string {
	var sb strings.Builder
	sb.WriteString("tunnel:")
	sb.WriteString(ta.Intermediary.Ref())
	sb.WriteString(":")
	sb.WriteString(ta.Target.Ref())
	sb.WriteString("~shs:")
	sb.WriteString(base64.StdEncoding.EncodeToString(ta.Target.PubKey()))
	return sb.String()
}

var (
	ErrNoTunnelAddr = errors.New("multiserver: not a tunnel address")
)

const tunnelPrefix = "tunnel:"

func ParseTunnelAddress(input string) (*TunnelAddress, error) {
	if !strings.HasPrefix(input, tunnelPrefix) {
		return nil, ErrNoTunnelAddr
	}

	input = input[len(tunnelPrefix):]

	parts := strings.Split(input, ":")
	if n := len(parts); n != 3 {
		return nil, fmt.Errorf("mutliserver: unexpected number of parts (%d)", n)
	}
	// assuming [intermediaryRef, targetRef~shs, targetPubKey]

	intermediary, err := refs.ParseFeedRef(parts[0])
	if err != nil {
		return nil, err
	}

	targetRefWithSHS := parts[1]
	if !strings.HasSuffix(targetRefWithSHS, "~shs") {
		return nil, fmt.Errorf("mutliserver: no ~shs: combo for target peer")
	}

	// slice of the ~shs
	targetRef := targetRefWithSHS[:len(targetRefWithSHS)-4]

	target, err := refs.ParseFeedRef(targetRef)
	if err != nil {
		return nil, err
	}

	// decode the targets public key
	pubKey, err := base64.StdEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, err
	}

	// check it matches the target
	if !bytes.Equal(target.PubKey(), pubKey) {
		return nil, fmt.Errorf("mutliserver: shs-portion doesn't equal target")
	}

	var ta TunnelAddress
	ta.Intermediary = intermediary
	ta.Target = target
	return &ta, nil
}
