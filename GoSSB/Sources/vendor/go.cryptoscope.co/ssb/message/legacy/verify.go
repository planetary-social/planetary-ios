// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package legacy how to encode and verify the current ssb messages.
// You most likely want to use legacy.Verify() in most cases.
//
// See https://spec.scuttlebutt.nz/feed/messages.html for more encoding details.
package legacy

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	refs "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/nacl/auth"
)

var (
	emptyMsgRef = refs.MessageRef{}
	emptyDMsg   = DeserializedMessage{}
)

type DeserializedMessage struct {
	Previous  *refs.MessageRef `json:"previous"`
	Author    refs.FeedRef     `json:"author"`
	Sequence  int64            `json:"sequence"`
	Timestamp float64          `json:"timestamp"`
	Hash      string           `json:"hash"`
	Content   json.RawMessage  `json:"content"`
}

// Verify takes an slice of bytes (like json.RawMessage) and uses EncodePreserveOrder to pretty print it.
// It then uses ExtractSignature and verifies the found signature against the author field of the message.
// If hmacSecret is non nil, it uses that as the Key for NACL crypto_auth() and verifies the signature against the hash of the message.
// At last it uses internalV8Binary to create a the SHA256 hash for the message key.
// If you find a buggy message, use `node ./encode_test.js $feedID` to generate a new testdata.zip
func Verify(raw []byte, hmacSecret *[32]byte) (refs.MessageRef, DeserializedMessage, error) {
	var buf bytes.Buffer
	return VerifyWithBuffer(raw, hmacSecret, &buf)
}

func runeLength(s string) int {
	runes := []rune(s)
	return len(runes)
}

func VerifyWithBuffer(raw []byte, hmacSecret *[32]byte, buf *bytes.Buffer) (refs.MessageRef, DeserializedMessage, error) {
	enc, err := PrettyPrint(raw, WithBuffer(buf), WithStrictOrderChecking(true))
	if err != nil {
		if len(raw) > 32 {
			raw = append(raw[:32], '.', '.', '.')
		}
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: could not encode message (%q): %w", raw, err)
	}

	// this unmarshal destroys it for the network layer but makes it easier to access its values
	var dmsg DeserializedMessage
	if err := json.Unmarshal(raw, &dmsg); err != nil {
		if len(raw) > 32 {
			raw = append(raw[:32], '.', '.', '.')
		}
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: could not json.Unmarshal message (%q): %w", raw, err)
	}

	// sha == scuttlebutt happend anyway
	if dmsg.Hash != "sha256" {
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: wrong hash value (scuttlebutt happend anyway)")
	}

	// check length
	if n := len(dmsg.Content); n < 1 {
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: has no content (%d)", n)
	} else if runeLength(string(dmsg.Content)) > 8192 {
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: message too large (%d)", n)
	}

	// some type consistency checks
	switch dmsg.Content[0] {
	case '{': // if it's a JSON object
		var typedContent struct {
			Type string
		}
		err = json.Unmarshal(dmsg.Content, &typedContent)
		if err != nil {
			return emptyMsgRef, emptyDMsg, err
		}

		// needs to have a type:string between 3 and 52 characters long (don't ask me why)
		if tlen := len(typedContent.Type); tlen < 3 || tlen > 52 {
			return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: scuttlebutt v1 requires a type field: %q", typedContent.Type)
		}

	case '"': // if it's a JSON string
		var justString string
		err = json.Unmarshal(dmsg.Content, &justString)
		if err != nil {
			return emptyMsgRef, emptyDMsg, err
		}

		// only allow known suffixes
		if !strings.HasSuffix(justString, ".box") && !strings.HasSuffix(justString, ".box2") {
			return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: scuttlebutt v1 private messages need to have the right suffix")
		}

	default:
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify: unexpected content: %q", dmsg.Content[0])
	}

	// to check the signature we need it to split it into message and signature
	msg, sig, err := ExtractSignature(enc)
	if err != nil {
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify(%s:%d): could not extract signature: %w", dmsg.Author.String(), dmsg.Sequence, err)
	}

	msg = maybeHMAC(msg, hmacSecret)

	if err := sig.Verify(msg, dmsg.Author); err != nil {
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify(%s:%d): %w", dmsg.Author.String(), dmsg.Sequence, err)
	}

	// hash the message - it's sadly the internal string rep of v8 that get's hashed, not the json string
	v8warp, err := InternalV8Binary(enc)
	if err != nil {
		return emptyMsgRef, emptyDMsg, fmt.Errorf("ssb Verify(%s:%d): could hash convert message: %w", dmsg.Author.String(), dmsg.Sequence, err)
	}
	h := sha256.New()
	io.Copy(h, bytes.NewReader(v8warp))

	mr, err := refs.NewMessageRefFromBytes(h.Sum(nil), refs.RefAlgoMessageSSB1)
	return mr, dmsg, err
}

// if HMAC mode is enabled for the network, we hash the message using nacl.Auth
// otherwise do nothing and just return the message as is
func maybeHMAC(message []byte, hmacSecret *[32]byte) []byte {
	if hmacSecret == nil {
		return message
	}

	// we are signing the keyed hash of the message instead
	mac := auth.Sum(message, hmacSecret)
	return mac[:]
}
