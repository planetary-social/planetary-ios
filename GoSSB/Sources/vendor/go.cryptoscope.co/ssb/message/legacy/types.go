// SPDX-License-Identifier: MIT

package legacy

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"io"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/nacl/auth"
)

type DeserializedMessage struct {
	Previous  *ssb.MessageRef  `json:"previous"`
	Author    ssb.FeedRef      `json:"author"`
	Sequence  margaret.BaseSeq `json:"sequence"`
	Timestamp float64          `json:"timestamp"`
	Hash      string           `json:"hash"`
	Content   json.RawMessage  `json:"content"`
}

type LegacyMessage struct {
	Previous  *ssb.MessageRef  `json:"previous"`
	Author    string           `json:"author"`
	Sequence  margaret.BaseSeq `json:"sequence"`
	Timestamp int64            `json:"timestamp"`
	Hash      string           `json:"hash"`
	Content   interface{}      `json:"content"`
}

// Sign preserves the filed order (up to content)
func (msg LegacyMessage) Sign(priv ed25519.PrivateKey, hmacSecret *[32]byte) (*ssb.MessageRef, []byte, error) {
	// flatten interface{} content value
	pp, err := jsonAndPreserve(msg)
	if err != nil {
		return nil, nil, errors.Wrap(err, "legacySign: error during sign prepare")
	}

	if hmacSecret != nil {
		mac := auth.Sum(pp, hmacSecret)
		pp = mac[:]
	}

	sig := ed25519.Sign(priv, pp)

	var signedMsg SignedLegacyMessage
	signedMsg.LegacyMessage = msg
	signedMsg.Signature = EncodeSignature(sig)

	// encode again, now with the signature to get the hash of the message
	ppWithSig, err := jsonAndPreserve(signedMsg)
	if err != nil {
		return nil, nil, errors.Wrap(err, "legacySign: error re-encoding signed message")
	}

	v8warp, err := InternalV8Binary(ppWithSig)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "legacySign: could not v8 escape message")
	}

	h := sha256.New()
	io.Copy(h, bytes.NewReader(v8warp))

	mr := &ssb.MessageRef{
		Hash: h.Sum(nil),
		Algo: ssb.RefAlgoMessageSSB1,
	}
	return mr, ppWithSig, nil
}

func jsonAndPreserve(msg interface{}) ([]byte, error) {
	var buf bytes.Buffer // might want to pass a bufpool around here
	if err := json.NewEncoder(&buf).Encode(msg); err != nil {
		return nil, errors.Wrap(err, "jsonAndPreserve: 1st-pass json flattning failed")
	}

	// pretty-print v8-like
	pp, err := EncodePreserveOrder(buf.Bytes())
	if err != nil {
		return nil, errors.Wrap(err, "jsonAndPreserve: preserver order failed")
	}
	return pp, nil
}

type SignedLegacyMessage struct {
	LegacyMessage
	Signature Signature `json:"signature"`
}
