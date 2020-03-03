// SPDX-License-Identifier: MIT

/* Package secrethandshake is a Go implementation of Dominic Tarr's secret-handshake: https://github.com/auditdrivencrypto/secret-handshake

Two instances of go-shs can secretly shake hands over a connection.

The implementation is compatible with the JS implementation.
Run `npm ci && go test -tags interop_nodejs`.
*/
package secrethandshake

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/sha512"

	"go.cryptoscope.co/secretstream/internal/lo25519"
	"go.cryptoscope.co/secretstream/secrethandshake/internal/extra25519"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/ed25519"
	"golang.org/x/crypto/nacl/box"
)

// State is the state each peer holds during the handshake
type State struct {
	appKey, secHash           []byte
	localAppMac, remoteAppMac []byte

	localExchange  CurveKeyPair
	local          EdKeyPair
	remoteExchange CurveKeyPair
	remotePublic   ed25519.PublicKey // long-term

	secret, secret2, secret3 [32]byte

	hello []byte

	aBob, bAlice [32]byte // better name? helloAlice, helloBob?
}

// EdKeyPair is a keypair for use with github.com/agl/ed25519
type EdKeyPair struct {
	Public ed25519.PublicKey
	Secret ed25519.PrivateKey
}

func NewKeyPair(public, secret []byte) (*EdKeyPair, error) {
	var kp EdKeyPair
	if n := len(secret); n != ed25519.PrivateKeySize {
		return nil, ErrKeySize{tipe: "private", n: n}
	}
	kp.Secret = secret

	if n := len(public); n != ed25519.PublicKeySize {
		return nil, ErrKeySize{tipe: "public", n: n}
	}

	if lo25519.IsEdLowOrder(public) {
		return nil, ErrInvalidKeyPair
	}
	kp.Public = public

	return &kp, nil
}

// CurveKeyPair is a keypair for use with github.com/agl/ed25519
type CurveKeyPair struct {
	Public [32]byte
	Secret [32]byte
}

// NewClientState initializes the state for the client side
func NewClientState(appKey []byte, local EdKeyPair, remotePublic ed25519.PublicKey) (*State, error) {
	state, err := newState(appKey, local)
	if err != nil {
		return state, err
	}

	state.remotePublic = remotePublic
	if l := len(state.remotePublic); l != ed25519.PublicKeySize {
		return nil, ErrKeySize{tipe: "remote/public", n: l}
	}

	return state, err
}

// NewServerState initializes the state for the server side
func NewServerState(appKey []byte, local EdKeyPair) (*State, error) {
	return newState(appKey, local)
}

// newState initializes the state needed by both client and server
func newState(appKey []byte, local EdKeyPair) (*State, error) {
	pubKey, secKey, err := box.GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}

	s := State{
		appKey:       appKey,
		remotePublic: make([]byte, ed25519.PublicKeySize),
	}
	copy(s.localExchange.Public[:], pubKey[:])
	copy(s.localExchange.Secret[:], secKey[:])
	s.local = local

	if l := len(s.local.Public); l != ed25519.PublicKeySize {
		return nil, ErrKeySize{tipe: "eph/public", n: l}
	}

	if l := len(s.local.Secret); l != ed25519.PrivateKeySize {
		return nil, ErrKeySize{tipe: "eph/private", n: l}
	}

	return &s, nil
}

// createChallenge returns a buffer with a challenge
func (s *State) createChallenge() []byte {
	appMacr := hmac.New(sha512.New, s.appKey[:32])
	appMacr.Write(s.localExchange.Public[:])
	s.localAppMac = appMacr.Sum(nil)[:32]
	return append(s.localAppMac, s.localExchange.Public[:]...)
}

// verifyChallenge returns whether the passed buffer is valid
func (s *State) verifyChallenge(ch []byte) bool {
	mac := ch[:32]
	remoteEphPubKey := ch[32:]

	appMac := hmac.New(sha512.New, s.appKey[:32])
	appMac.Write(remoteEphPubKey)
	ok := hmac.Equal(appMac.Sum(nil)[:32], mac)

	copy(s.remoteExchange.Public[:], remoteEphPubKey)
	s.remoteAppMac = mac

	var sec [32]byte
	curve25519.ScalarMult(&sec, &s.localExchange.Secret, &s.remoteExchange.Public)
	copy(s.secret[:], sec[:])

	secHasher := sha256.New()
	secHasher.Write(s.secret[:])
	s.secHash = secHasher.Sum(nil)

	return ok
}

// createClientAuth returns a buffer containing a clientAuth message
func (s *State) createClientAuth() []byte {
	var curveRemotePubKey [32]byte
	if !extra25519.PublicKeyToCurve25519(&curveRemotePubKey, s.remotePublic) {
		panic("secrethandshake: could not convert remote to curve key")
	}
	var aBob [32]byte
	curve25519.ScalarMult(&aBob, &s.localExchange.Secret, &curveRemotePubKey)
	copy(s.aBob[:], aBob[:])

	secHasher := sha256.New()
	secHasher.Write(s.appKey)
	secHasher.Write(s.secret[:])
	secHasher.Write(s.aBob[:])
	copy(s.secret2[:], secHasher.Sum(nil))

	var sigMsg bytes.Buffer
	sigMsg.Write(s.appKey)
	sigMsg.Write(s.remotePublic[:])
	sigMsg.Write(s.secHash)

	sig := ed25519.Sign(s.local.Secret, sigMsg.Bytes())

	var helloBuf bytes.Buffer
	helloBuf.Write(sig[:])
	helloBuf.Write(s.local.Public[:])
	s.hello = helloBuf.Bytes()

	out := make([]byte, 0, len(s.hello)-box.Overhead)
	var n [24]byte
	out = box.SealAfterPrecomputation(out, s.hello, &n, &s.secret2)
	return out
}

var nullHello [ed25519.SignatureSize + ed25519.PublicKeySize]byte

// verifyClientAuth returns whether a buffer contains a valid clientAuth message
func (s *State) verifyClientAuth(data []byte) bool {
	var cvSec, aBob [32]byte
	extra25519.PrivateKeyToCurve25519(&cvSec, s.local.Secret)
	curve25519.ScalarMult(&aBob, &cvSec, &s.remoteExchange.Public)
	copy(s.aBob[:], aBob[:])

	secHasher := sha256.New()
	secHasher.Write(s.appKey)
	secHasher.Write(s.secret[:])
	secHasher.Write(s.aBob[:])
	copy(s.secret2[:], secHasher.Sum(nil))

	s.hello = make([]byte, 0, len(data)-16)

	var nonce [24]byte // always 0?
	var openOk bool
	s.hello, openOk = box.OpenAfterPrecomputation(s.hello, data, &nonce, &s.secret2)

	var sig = make([]byte, ed25519.SignatureSize)
	var public = make([]byte, ed25519.PublicKeySize)
	/* TODO: is this const time!?!

	   this is definetly not:
	   if !openOK {
	   	s.hello = nullHello
	   }
	   copy(sig, ...)
	   copy(pub, ...)
	*/
	if openOk {
		copy(sig, s.hello[:ed25519.SignatureSize])
		copy(public[:], s.hello[ed25519.SignatureSize:])

	} else {
		copy(sig, nullHello[:ed25519.SignatureSize])
		copy(public[:], nullHello[ed25519.SignatureSize:])
	}

	if lo25519.IsEdLowOrder(sig[:32]) {
		openOk = false
	}

	var sigMsg bytes.Buffer
	sigMsg.Write(s.appKey)
	sigMsg.Write(s.local.Public[:])
	sigMsg.Write(s.secHash)
	verifyOk := ed25519.Verify(public, sigMsg.Bytes(), sig)

	copy(s.remotePublic, public)
	return openOk && verifyOk
}

// createServerAccept returns a buffer containing a serverAccept message
func (s *State) createServerAccept() []byte {
	var curveRemotePubKey [32]byte
	if !extra25519.PublicKeyToCurve25519(&curveRemotePubKey, s.remotePublic) {
		panic("secrethandshake: could not convert remote to curve key")
	}
	var bAlice [32]byte
	curve25519.ScalarMult(&bAlice, &s.localExchange.Secret, &curveRemotePubKey)
	copy(s.bAlice[:], bAlice[:])

	secHasher := sha256.New()
	secHasher.Write(s.appKey)
	secHasher.Write(s.secret[:])
	secHasher.Write(s.aBob[:])
	secHasher.Write(s.bAlice[:])
	copy(s.secret3[:], secHasher.Sum(nil))

	var sigMsg bytes.Buffer
	sigMsg.Write(s.appKey)
	sigMsg.Write(s.hello[:])
	sigMsg.Write(s.secHash)

	okay := ed25519.Sign(s.local.Secret, sigMsg.Bytes())

	var out = make([]byte, 0, len(okay)+16)
	var nonce [24]byte // always 0?
	return box.SealAfterPrecomputation(out, okay[:], &nonce, &s.secret3)
}

// verifyServerAccept returns whether the passed buffer contains a valid serverAccept message
func (s *State) verifyServerAccept(boxedOkay []byte) bool {
	var curveLocalSec [32]byte
	extra25519.PrivateKeyToCurve25519(&curveLocalSec, s.local.Secret)
	var bAlice [32]byte
	curve25519.ScalarMult(&bAlice, &curveLocalSec, &s.remoteExchange.Public)
	copy(s.bAlice[:], bAlice[:])

	secHasher := sha256.New()
	secHasher.Write(s.appKey)
	secHasher.Write(s.secret[:])
	secHasher.Write(s.aBob[:])
	secHasher.Write(s.bAlice[:])
	copy(s.secret3[:], secHasher.Sum(nil))

	var nonce [24]byte // always 0?
	sig := make([]byte, 0, len(boxedOkay)-16)
	sig, openOk := box.OpenAfterPrecomputation(nil, boxedOkay, &nonce, &s.secret3)

	var sigMsg bytes.Buffer
	sigMsg.Write(s.appKey)
	sigMsg.Write(s.hello[:])
	sigMsg.Write(s.secHash)

	verifyOk := ed25519.Verify(s.remotePublic, sigMsg.Bytes(), sig)
	return verifyOk && openOk
}

// cleanSecrets overwrites all intermediate secrets and copies the final secret to s.secret
func (s *State) cleanSecrets() {
	var zeros [64]byte

	copy(s.secHash, zeros[:])
	copy(s.secret[:], zeros[:]) // redundant
	copy(s.aBob[:], zeros[:])
	copy(s.bAlice[:], zeros[:])

	h := sha256.New()
	h.Write(s.secret3[:])
	copy(s.secret[:], h.Sum(nil))
	copy(s.secret2[:], zeros[:])
	copy(s.secret3[:], zeros[:])
	copy(s.localExchange.Secret[:], zeros[:])
}

// Remote returns the public key of the remote party
func (s *State) Remote() []byte {
	return s.remotePublic[:]
}

// GetBoxstreamEncKeys returns the encryption key and nonce suitable for boxstream
func (s *State) GetBoxstreamEncKeys() ([32]byte, [24]byte) {
	// TODO: error before cleanSecrets() has been called?

	var enKey [32]byte
	h := sha256.New()
	h.Write(s.secret[:])
	h.Write(s.remotePublic[:])
	copy(enKey[:], h.Sum(nil))

	var nonce [24]byte
	copy(nonce[:], s.remoteAppMac)
	return enKey, nonce
}

// GetBoxstreamDecKeys returns the decryption key and nonce suitable for boxstream
func (s *State) GetBoxstreamDecKeys() ([32]byte, [24]byte) {
	// TODO: error before cleanSecrets() has been called?

	var deKey [32]byte
	h := sha256.New()
	h.Write(s.secret[:])
	h.Write(s.local.Public[:])
	copy(deKey[:], h.Sum(nil))

	var nonce [24]byte
	copy(nonce[:], s.localAppMac)
	return deKey, nonce
}
