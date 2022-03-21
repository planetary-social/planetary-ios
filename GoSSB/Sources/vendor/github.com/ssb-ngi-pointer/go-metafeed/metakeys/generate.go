// SPDX-FileCopyrightText: 2021 The go-metafeed Authors
//
// SPDX-License-Identifier: MIT

package metakeys

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"

	refs "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/hkdf"
)

// Some constants
const (
	SeedLength = 64

	infoPrefix = "ssb-meta-feed-seed-v1:"

	salt = "ssb"
)

// GenerateSeed returns a fresh seed of Seedlength bytes, using crypto/rand as a source
func GenerateSeed() ([]byte, error) {
	sbuf := make([]byte, SeedLength)
	_, err := io.ReadFull(rand.Reader, sbuf)
	return sbuf, err
}

// DeriveFromSeed generates a new KeyPair using the seed and label for hkdf derivation
func DeriveFromSeed(seed []byte, label string, algo refs.RefAlgo) (KeyPair, error) {
	// TODO: confirm with @arj
	// if n := len(seed); n != SeedLength {
	// 	return KeyPair{}, fmt.Errorf("metakeys: seed has wrong length: %d", n)
	// }

	if len(label) == 0 {
		return KeyPair{}, fmt.Errorf("metakeys: label can't be empty")
	}

	derived := make([]byte, ed25519.SeedSize)
	r := hkdf.New(sha256.New, seed, []byte(salt), append([]byte(infoPrefix), label...))
	_, err := r.Read(derived)
	if err != nil {
		return KeyPair{}, fmt.Errorf("metakeys: error deriving key: %w", err)
	}

	public, secret, err := ed25519.GenerateKey(bytes.NewReader(derived))
	if err != nil {
		return KeyPair{}, fmt.Errorf("metakeys: failed to generate keypair from derived data: %w", err)
	}

	feed, err := refs.NewFeedRefFromBytes(public, algo)
	return KeyPair{
		Seed:       seed,
		Feed:       feed,
		PrivateKey: secret,
	}, err
}

// KeyPair is a bendybutt metafeed keypair and the corresponding feed refrence.
// It also keeps the seed around for deriving further keys from it.
type KeyPair struct {
	Seed []byte

	Feed       refs.FeedRef
	PrivateKey ed25519.PrivateKey
}

// ID returns the feed reference of the keypair (implements ssb.KeyPair)
func (kp KeyPair) ID() refs.FeedRef {
	return kp.Feed
}

// Secret returns the private part of the keypair (implements ssb.KeyPair)
func (kp KeyPair) Secret() ed25519.PrivateKey {
	return kp.PrivateKey
}

var (
	_ json.Marshaler   = (*KeyPair)(nil)
	_ json.Unmarshaler = (*KeyPair)(nil)
)

type typedKeyPair struct {
	Type       string
	Seed       []byte
	Feed       refs.FeedRef
	PrivateKey ed25519.PrivateKey
}

// MarshalJSON turns a keypair into json data adding a `Type: "bendy-butt"` to it
func (kp KeyPair) MarshalJSON() ([]byte, error) {
	var tkp = typedKeyPair{"bendy-butt", kp.Seed, kp.Feed, kp.PrivateKey}
	return json.Marshal(tkp)
}

// UnmarshalJSON checks if the input data is indeed an object that descripts a bendy-butt keypair
func (kp *KeyPair) UnmarshalJSON(input []byte) error {
	var newKp typedKeyPair
	err := json.Unmarshal(input, &newKp)
	if err != nil {
		return err
	}

	if newKp.Type != "bendy-butt" {
		return fmt.Errorf("invalid keypair type: %q", newKp.Type)
	}

	if newKp.Feed.Algo() != refs.RefAlgoFeedBendyButt {
		return fmt.Errorf("input data is not a bendybutt metafeed keypair")
	}

	if n := len(newKp.PrivateKey); n != ed25519.PrivateKeySize {
		return fmt.Errorf("private key has the wrong size: %d", n)
	}

	if n := len(newKp.Seed); n != SeedLength {
		return fmt.Errorf("seed data has the wrong size: %d", n)
	}

	// copy values
	kp.Feed = newKp.Feed
	kp.Seed = newKp.Seed
	kp.PrivateKey = newKp.PrivateKey

	return nil
}
