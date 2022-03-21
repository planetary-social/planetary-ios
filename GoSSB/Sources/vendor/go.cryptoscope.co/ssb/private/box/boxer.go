// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package box

import (
	"bytes"
	"crypto/rand"
	"fmt"
	"io"

	refs "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/nacl/box"
	"golang.org/x/crypto/nacl/secretbox"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/extra25519"
)

var ErrPrivateMessageDecryptFailed = fmt.Errorf("decode pm: decryption failed")

const (
	maxRecps     = 255                         // 1 byte for recipient count
	rcptSboxSize = 32 + 1 + secretbox.Overhead // secretbox secret + rcptCount + overhead
)

func NewBoxer(r io.Reader) *Boxer {
	if r == nil {
		r = rand.Reader
	}
	return &Boxer{rand: r}
}

type Boxer struct {
	rand io.Reader
}

func (bxr *Boxer) Encrypt(clearMsg []byte, rcpts ...refs.FeedRef) ([]byte, error) {
	n := len(rcpts)
	if n <= 0 || n > maxRecps {
		return nil, fmt.Errorf("encrypt pm: wrong number of recipients: %d", n)
	}

	// ephemeral one time, single-use key for this message
	ephPub, ephSecret, err := box.GenerateKey(bxr.rand)
	if err != nil {
		return nil, fmt.Errorf("encrypt pm: could not make one-time sender keypair")
	}

	var (
		cipheredMsg bytes.Buffer // writes to a buffer don't fail (out-of-memory is a panic)
		nonce       [24]byte
		skey        [32]byte // random secret for the content box
		smsg        [33]byte
	)

	io.ReadFull(bxr.rand, nonce[:])
	io.ReadFull(bxr.rand, skey[:])

	// construct _symetric secret_ for the content
	smsg[0] = byte(n)
	copy(smsg[1:], skey[:])

	// write header
	cipheredMsg.Write(nonce[:])
	cipheredMsg.Write(ephPub[:])

	if n := cipheredMsg.Len(); n != 32+24 {
		return nil, fmt.Errorf("encrypt pm: wrong number of header bytes %d", n)
	}

	// make a key box for each recipient
	for _, r := range rcpts {
		var (
			messageShared [32]byte // the recipients sbox secret
			cvPub         [32]byte // recpt' pub in curve space
		)

		extra25519.PublicKeyToCurve25519(&cvPub, r.PubKey())
		curve25519.ScalarMult(&messageShared, ephSecret, &cvPub)

		boxedMsgKey := secretbox.Seal(nil, smsg[:], &nonce, &messageShared)
		cipheredMsg.Write(boxedMsgKey)
	}

	cipher := secretbox.Seal(nil, clearMsg, &nonce, &skey)
	cipheredMsg.Write(cipher)

	return cipheredMsg.Bytes(), nil
}

func (bxr *Boxer) Decrypt(recpt ssb.KeyPair, rawMsg []byte) ([]byte, error) {
	if len(rawMsg) < 122 {
		return nil, fmt.Errorf("decode pm: sorry message seems short?")
	}

	var nonce [24]byte
	var hdrPub [32]byte

	const start = 24 + 32

	copy(nonce[:], rawMsg[:24])
	copy(hdrPub[:], rawMsg[24:start])

	// construct the key that should/can open the header sbox _for us_
	var messageShared, cvSec [32]byte
	extra25519.PrivateKeyToCurve25519(&cvSec, recpt.Secret())
	curve25519.ScalarMult(&messageShared, &cvSec, &hdrPub)

	var (
		cnt  int              // number of recipients
		skey [32]byte         // random key for the box
		curr = rawMsg[start:] // pointer into the message for finding recpt' sbox
	)

	for i := 0; i < maxRecps; i++ {
		if len(curr) < rcptSboxSize { // prevent seeking off the msgs end
			break
		}

		decrypted, ok := secretbox.Open(nil, curr[:rcptSboxSize], &nonce, &messageShared)
		if !ok {
			curr = curr[rcptSboxSize:]
			continue
		}

		cnt = int(decrypted[0])
		copy(skey[:], decrypted[1:])
		break
	}

	content, ok := secretbox.Open(nil, rawMsg[start+cnt*rcptSboxSize:], &nonce, &skey)
	if cnt == 0 || !ok {
		return nil, ErrPrivateMessageDecryptFailed
	}

	return content, nil
}
