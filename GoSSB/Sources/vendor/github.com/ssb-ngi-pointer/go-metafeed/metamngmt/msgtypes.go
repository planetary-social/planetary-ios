// SPDX-FileCopyrightText: 2021 The go-metafeed Authors
//
// SPDX-License-Identifier: MIT

// Package metamngmt contains all the managment types that one needs to have in order to work with metafeeds.
//
// This includes:
//  - 'metafeed/seed'
//  - 'metafeed/add'
//  - 'metafeed/announce'
//  - 'metafeed/tombstone'
package metamngmt

import (
	"fmt"

	"github.com/zeebo/bencode"
	refs "go.mindeco.de/ssb-refs"
)

type Typed struct {
	Type string `json:"type"`
}

const (
	typeAddExisting = "metafeed/add/existing"
	typeAddDerived  = "metafeed/add/derived"
)

// AddDerived links the new sub feed with the main (meta)feed using a new message on the meta feed signed by both the main feed and the meta feed.
type AddDerived struct {
	Type string `json:"type"`

	FeedPurpose string `json:"feedpurpose"`

	SubFeed  refs.FeedRef `json:"subfeed"`
	MetaFeed refs.FeedRef `json:"metafeed"`

	Nonce []byte `json:"nonce"`

	Tangles refs.Tangles `json:"tangles"`

	metadata map[string]string
}

// NewAddDerivedMessage just initializes type and the passed fields.
// Callers need to set the right tangle point themselves afterwards. If the message has metadata that needs to be added,
// function AddDerived.InsertMetadata should be used.
func NewAddDerivedMessage(meta, sub refs.FeedRef, purpose string, nonce []byte) AddDerived {
	return AddDerived{
		Type: typeAddDerived,

		SubFeed:  sub,
		MetaFeed: meta,

		FeedPurpose: purpose,

		Nonce: nonce,

		Tangles: make(refs.Tangles),

		metadata: make(map[string]string),
	}
}

// InsertMetadata enhances an existing AddDerived message with metadata, returning an error if the passed metadata
// contains an unsupported key.
func (derived *AddDerived) InsertMetadata(metadata map[string]string) error {
	if derived.metadata == nil {
		derived.metadata = make(map[string]string)
	}
	// attach any metadata (e.g. query info used in for index feeds), if any
	for key, value := range metadata {
		switch key {
		case "querylang", "query":
			// copy key + value from passed in map
			derived.metadata[key] = value
		default:
			return fmt.Errorf("AddDerived does not support metadata key: %s", key)
		}
	}
	return nil
}

func (derived *AddDerived) GetMetadata(key string) (string, bool) {
	if derived.metadata == nil {
		return "", false
	}
	val, has := derived.metadata[key]
	return val, has
}

var (
	_ bencode.Marshaler   = (*AddDerived)(nil)
	_ bencode.Unmarshaler = (*AddDerived)(nil)
)

// AddExisting links the new sub feed with the main (meta)feed using a new message on the meta feed signed by both the main feed and the meta feed.
type AddExisting struct {
	Type string `json:"type"`

	FeedPurpose string `json:"feedpurpose"`

	SubFeed  refs.FeedRef `json:"subfeed"`
	MetaFeed refs.FeedRef `json:"metafeed"`

	Tangles refs.Tangles `json:"tangles"`
}

// NewAddExistingMessage just initializes type and the passed fields.
// Callers need to set the right tangle point themselves afterwards.
//
// Format of the message (in Bendy Butt binary notation, see https://github.com/ssb-ngi-pointer/bendy-butt-spec):
//  "type" => "metafeed/add/existing",
//  "feedpurpose" => "main",
//  "subfeed" => (BFE-encoded feed ID for the 'main' feed),
//  "metafeed" => (BFE-encoded Bendy Butt feed ID for the meta feed),
//  "tangles" => {
//    "metafeed" => {
//      "root" => (BFE nil),
//      "previous" => (BFE nil)
//    }
//  }
func NewAddExistingMessage(meta, sub refs.FeedRef, purpose string) AddExisting {
	return AddExisting{
		Type: typeAddExisting,

		SubFeed:  sub,
		MetaFeed: meta,

		FeedPurpose: purpose,

		Tangles: make(refs.Tangles),
	}
}

var (
	_ bencode.Marshaler   = (*AddExisting)(nil)
	_ bencode.Unmarshaler = (*AddExisting)(nil)
)

// Announce is used in order for existing applications to know that a feed supports meta feeds.
// This message is created on the main feed.
type Announce struct {
	Type     string       `json:"type"`
	MetaFeed refs.FeedRef `json:"metafeed"`
	Tangles  refs.Tangles `json:"tangles"`
}

// Tombstone is used to end the lifetime of a subfeed
type Tombstone struct {
	Type     string       `json:"type"`
	SubFeed  refs.FeedRef `json:"subfeed"`
	MetaFeed refs.FeedRef `json:"metafeed"`

	Tangles refs.Tangles `json:"tangles"`
}

// NewTombstoneMessage returns a new Tombstone message.
// Callers need to set the right tangle point themselves afterwards.
func NewTombstoneMessage(sub, meta refs.FeedRef) Tombstone {
	return Tombstone{
		Type: "metafeed/tombstone",

		SubFeed:  sub,
		MetaFeed: meta,

		Tangles: make(refs.Tangles),
	}
}

var (
	_ bencode.Marshaler   = (*Tombstone)(nil)
	_ bencode.Unmarshaler = (*Tombstone)(nil)
)
