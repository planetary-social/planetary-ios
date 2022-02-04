// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package extra25519 implements the key conversion from ed25519 to curve25519. Nothing more.
package extra25519

import (
	"crypto/sha512"

	"filippo.io/edwards25519"
	"golang.org/x/crypto/ed25519"

	"go.cryptoscope.co/ssb/internal/lo25519"
)

// PrivateKeyToCurve25519 converts an ed25519 private key into a corresponding
// curve25519 private key such that the resulting curve25519 public key will
// equal the result from PublicKeyToCurve25519.
func PrivateKeyToCurve25519(curve25519Private *[32]byte, privateKey ed25519.PrivateKey) {
	h := sha512.New()
	h.Write(privateKey[:32])
	digest := h.Sum(nil)

	digest[0] &= 248
	digest[31] &= 127
	digest[31] |= 64

	copy(curve25519Private[:], digest)
}

// PublicKeyToCurve25519 converts an Ed25519 public key into the curve25519
// public key that would be generated from the same private key.
func PublicKeyToCurve25519(curveBytes *[32]byte, edBytes ed25519.PublicKey) bool {
	if lo25519.IsEdLowOrder(edBytes) {
		return false
	}

	edPoint, err := new(edwards25519.Point).SetBytes(edBytes)
	if err != nil {
		return false
	}

	copy(curveBytes[:], edPoint.BytesMontgomery())
	return true
}
