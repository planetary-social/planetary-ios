// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package keys

import (
	"encoding/binary"
	"fmt"

	refs "go.mindeco.de/ssb-refs"
)

type KeyScheme string

func (ks KeyScheme) Valid() bool {
	return ks == SchemeLargeSymmetricGroup ||
		ks == SchemeDiffieStyleConvertedED25519 ||
		ks == SchemeFeedMessageSigningKey ||
		ks == SchemeMetafeedSubkey
}

const (
	SchemeLargeSymmetricGroup         KeyScheme = "envelope-large-symmetric-group"
	SchemeDiffieStyleConvertedED25519 KeyScheme = "envelope-id-based-dm-converted-ed25519"
	SchemeFeedMessageSigningKey       KeyScheme = "feed-message-signing-key"
	SchemeMetafeedSubkey              KeyScheme = "metafeed-subkey"
)

type ID []byte

func IDFromFeed(r refs.FeedRef) ID {
	// might be cleaner but needs changes elsewhere (that should probably use this func)
	// idBytes, err := tfk.Encode(r)
	// if err != nil {
	// 	panic(err)
	// }
	idBytes := r.PubKey()
	return ID(idBytes)
}

type idxKey struct {
	ks KeyScheme
	id ID
}

func (idxk *idxKey) Len() int {
	return 4 + len(idxk.id) + len(idxk.ks)
}

func (idxk *idxKey) Read(data []byte) (int64, error) {
	if !idxk.ks.Valid() {
		return -1, Error{Code: ErrorCodeInvalidKeyScheme}
	}

	if len(data) < idxk.Len() {
		return -1, fmt.Errorf("buffer too short: need %d, got %d", idxk.Len(), len(data))
	}

	var off int

	binary.LittleEndian.PutUint16(data[off:], uint16(len(idxk.ks)))
	off += 2

	copy(data[off:], []byte(idxk.ks))
	off += len(idxk.ks)

	binary.LittleEndian.PutUint16(data[off:], uint16(len(idxk.id)))
	off += 2

	copy(data[off:], []byte(idxk.id))

	return int64(idxk.Len()), nil
}

func (idxk *idxKey) MarshalBinary() ([]byte, error) {
	data := make([]byte, idxk.Len())
	_, err := idxk.Read(data)
	return data, err
}

func (idxk *idxKey) Write(data []byte) (int64, error) {
	var off int

	if diff := len(data) - off; diff < 2 {
		return -1, fmt.Errorf("data too short to read type length")
	}

	typeLen := binary.LittleEndian.Uint16(data[0:])
	off += 2

	if diff := len(data) - off; diff < int(typeLen)+2 {
		return -1, fmt.Errorf("invalid key - claimed type length exceeds buffer")
	}

	idxk.ks = KeyScheme(data[off : off+int(typeLen)])
	if !idxk.ks.Valid() {
		return -1, fmt.Errorf("invalid keytype")
	}
	off += int(typeLen)

	idLen := binary.LittleEndian.Uint16(data[off:])
	off += 2

	if diff := len(data) - off; diff < int(idLen) {
		return -1, fmt.Errorf("invalid key - claimed id length exceeds buffer")
	}

	if len(idxk.id) < int(idLen) {
		idxk.id = make(ID, idLen)
	}

	copy(idxk.id, ID(data[off:]))

	return int64(idxk.Len()), nil
}

func (idxk *idxKey) UnmarshalBinary(data []byte) error {
	_, err := idxk.Write(data)
	return err
}
