// +build dev

// SPDX-License-Identifier: MIT

package secrethandshake

// nice for debugging purposes. no production code
import (
	"bytes"
	"encoding/hex"
)

func (s *State) String() string {
	buf := &bytes.Buffer{}

	buf.WriteString("State {")

	appKeyHex := make([]byte, 2*len(s.appKey))
	hex.Encode(appKeyHex, s.appKey)
	buf.WriteString("\n\tappKey: ")
	buf.Write(appKeyHex)

	secHashHex := make([]byte, 2*len(s.secHash))
	hex.Encode(secHashHex, s.secHash)
	buf.WriteString("\n\tsecHash: ")
	buf.Write(secHashHex)

	secretHex := make([]byte, 2*len(s.secret))
	hex.Encode(secretHex, s.secret[:])
	buf.WriteString("\n\tsecret: ")
	buf.Write(secretHex)

	secret2Hex := make([]byte, 2*len(s.secret2))
	hex.Encode(secret2Hex, s.secret2[:])
	buf.WriteString("\n\tsecret2: ")
	buf.Write(secret2Hex)

	secret3Hex := make([]byte, 2*len(s.secret3))
	hex.Encode(secret3Hex, s.secret3[:])
	buf.WriteString("\n\tsecret3: ")
	buf.Write(secret3Hex)

	localPublicHex := make([]byte, 2*len(s.local.Public))
	hex.Encode(localPublicHex, s.local.Public[:])
	buf.WriteString("\n\tlocalPublic: ")
	buf.Write(localPublicHex)

	localEphPublicHex := make([]byte, 2*len(s.localExchange.Public))
	hex.Encode(localEphPublicHex, s.localExchange.Public[:])
	buf.WriteString("\n\tlocalEphPublic: ")
	buf.Write(localEphPublicHex)

	remotePublicHex := make([]byte, 2*len(s.remotePublic))
	hex.Encode(remotePublicHex, s.remotePublic[:])
	buf.WriteString("\n\tremotePublic: ")
	buf.Write(remotePublicHex)

	remoteEphPublicHex := make([]byte, 2*len(s.remoteExchange.Public))
	hex.Encode(remoteEphPublicHex, s.remoteExchange.Public[:])
	buf.WriteString("\n\tremoteEphPublic: ")
	buf.Write(remoteEphPublicHex)

	bAliceHex := make([]byte, 2*len(s.bAlice))
	hex.Encode(bAliceHex, s.bAlice[:])
	buf.WriteString("\n\tbAlice: ")
	buf.Write(bAliceHex)

	aBobHex := make([]byte, 2*len(s.aBob))
	hex.Encode(aBobHex, s.aBob[:])
	buf.WriteString("\n\taBob: ")
	buf.Write(aBobHex)

	remoteHelloHex := make([]byte, 2*len(s.hello))
	hex.Encode(remoteHelloHex, s.hello[:])
	buf.WriteString("\n\tremoteHello: ")
	buf.Write(remoteHelloHex)

	buf.WriteString("\n}")
	return buf.String()
}
