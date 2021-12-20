// SPDX-License-Identifier: MIT

package legacy

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"

	refs "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/nacl/auth"
)

type DeserializedMessage struct {
	Previous  *refs.MessageRef `json:"previous"`
	Author    refs.FeedRef     `json:"author"`
	Sequence  int64            `json:"sequence"`
	Timestamp float64          `json:"timestamp"`
	Hash      string           `json:"hash"`
	Content   json.RawMessage  `json:"content"`
}

type LegacyMessage struct {
	Previous  *refs.MessageRef `json:"previous"`
	Author    string           `json:"author"`
	Sequence  int64            `json:"sequence"`
	Timestamp int64            `json:"timestamp"`
	Hash      string           `json:"hash"`
	Content   interface{}      `json:"content"`
}

// Sign preserves the filed order (up to content)
func (msg LegacyMessage) Sign(priv ed25519.PrivateKey, hmacSecret *[32]byte) (refs.MessageRef, []byte, error) {
	// flatten interface{} content value
	pp, err := jsonAndPreserve(msg)
	if err != nil {
		return refs.MessageRef{}, nil, fmt.Errorf("legacySign: error during sign prepare: %w", err)
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
		return refs.MessageRef{}, nil, fmt.Errorf("legacySign: error re-encoding signed message: %w", err)
	}

	v8warp, err := InternalV8Binary(ppWithSig)
	if err != nil {
		return refs.MessageRef{}, nil, fmt.Errorf("legacySign: could not v8 escape message: %w", err)
	}

	h := sha256.New()
	io.Copy(h, bytes.NewReader(v8warp))

	mr, err := refs.NewMessageRefFromBytes(h.Sum(nil), refs.RefAlgoMessageSSB1)
	return mr, ppWithSig, err
}

func jsonAndPreserve(msg interface{}) ([]byte, error) {
	var buf bytes.Buffer // might want to pass a bufpool around here
	if err := json.NewEncoder(&buf).Encode(msg); err != nil {
		return nil, fmt.Errorf("jsonAndPreserve: 1st-pass json flattning failed: %w", err)
	}

	// pretty-print v8-like
	pp, err := PrettyPrint(buf.Bytes())
	if err != nil {
		return nil, fmt.Errorf("jsonAndPreserve: preserver order failed: %w", err)
	}
	return pp, nil
}

type SignedLegacyMessage struct {
	LegacyMessage
	Signature Signature `json:"signature"`
}
