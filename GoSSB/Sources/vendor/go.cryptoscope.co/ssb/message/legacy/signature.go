// SPDX-License-Identifier: MIT

package legacy

import (
	"encoding/base64"
	"fmt"
	"strings"

	refs "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/ed25519"
)

type Signature string

func EncodeSignature(s []byte) Signature {
	return Signature(base64.StdEncoding.EncodeToString(s) + ".sig.ed25519")
}

type SigAlgo int

const (
	SigAlgoInvalid SigAlgo = iota
	SigAlgoEd25519
)

func (s Signature) Algo() SigAlgo {
	parts := strings.Split(string(s), ".")
	if len(parts) != 3 || parts[1] != "sig" {
		return SigAlgoInvalid
	}
	switch strings.ToLower(parts[2]) {
	case "ed25519":
		return SigAlgoEd25519
	}
	return SigAlgoInvalid
}

func (s Signature) Bytes() ([]byte, error) {
	parts := strings.Split(string(s), ".")
	if n := len(parts); n < 1 {
		return nil, fmt.Errorf("signature: expected at least one part - got %d", n)
	}
	b64 := parts[0]
	return base64.StdEncoding.DecodeString(b64)
}

func (s Signature) Verify(content []byte, r refs.FeedRef) error {
	switch s.Algo() {
	case SigAlgoEd25519:
		if r.Algo() != refs.RefAlgoFeedSSB1 {
			return fmt.Errorf("invalid feed algorithm")
		}

		b, err := s.Bytes()
		if err != nil {
			return fmt.Errorf("unpack failed: %w", err)
		}

		if ed25519.Verify(r.PubKey(), content, b) {
			return nil
		}

		return fmt.Errorf("invalid signature")
	default:
		return fmt.Errorf("unknown signature algorithm")
	}
}
