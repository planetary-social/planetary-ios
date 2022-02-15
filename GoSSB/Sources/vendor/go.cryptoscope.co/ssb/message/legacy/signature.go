// SPDX-License-Identifier: MIT

package legacy

import (
	"encoding/base64"
	"strings"

	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
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

func (s Signature) Raw() ([]byte, error) {
	b64 := strings.Split(string(s), ".")[0]
	return base64.StdEncoding.DecodeString(b64)
}

func (s Signature) Verify(content []byte, r *ssb.FeedRef) error {
	switch s.Algo() {
	case SigAlgoEd25519:
		if r.Algo != ssb.RefAlgoFeedSSB1 {
			return errors.Errorf("sbot: invalid signature algorithm")
		}
		b, err := s.Raw()
		if err != nil {
			return errors.Wrap(err, "verify: raw unpack failed")
		}
		if ed25519.Verify(r.PubKey(), content, b) {
			return nil
		}
		return errors.Errorf("sbot: invalid signature")
	default:
		return errors.Errorf("verify: unknown Algo")
	}
}
