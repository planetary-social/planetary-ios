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
	"github.com/zeebo/bencode"
	refs "go.mindeco.de/ssb-refs"
)

type Typed struct {
	Type string `json:"type"`
}

// Seed is used to encrypt the seed as a private message to the main feed.
// By doing this we allow the main feed to reconstruct the meta feed and all sub feeds from this seed.
type Seed struct {
	Type     string       `json:"type"`
	MetaFeed refs.FeedRef `json:"metafeed"`
	Seed     Base64String `json:"seed"`
}

// NewSeedMessage returns a new Seed with the type: alread set
func NewSeedMessage(meta refs.FeedRef, seed []byte) Seed {
	return Seed{
		Type:     "metafeed/seed",
		MetaFeed: meta,
		Seed:     seed,
	}
}

var (
	_ bencode.Marshaler   = (*Seed)(nil)
	_ bencode.Unmarshaler = (*Seed)(nil)
)

// Add links the new sub feed with the main (meta)feed using a new message on the meta feed signed by both the main feed and the meta feed.
type Add struct {
	Type string `json:"type"`

	FeedPurpose string `json:"feedpurpose"`

	SubFeed  refs.FeedRef `json:"subfeed"`
	MetaFeed refs.FeedRef `json:"metafeed"`

	Nonce Base64String `json:"nonce"`

	Tangles refs.Tangles `json:"tangles"`
}

// NewAddMessage just initializes type and the passed fields.
// Callers need to set the right tangle point themselves afterwards.
func NewAddMessage(meta, sub refs.FeedRef, purpose string, nonce []byte) Add {
	return Add{
		Type: "metafeed/add",

		SubFeed:  sub,
		MetaFeed: meta,

		FeedPurpose: purpose,

		Nonce: nonce,

		Tangles: make(refs.Tangles),
	}
}

var (
	_ bencode.Marshaler   = (*Add)(nil)
	_ bencode.Unmarshaler = (*Add)(nil)
)

// Announce is used in order for existing applications to know that a feed supports meta feeds.
// This message is created on the main feed.
type Announce struct {
	Type     string       `json:"type"`
	MetaFeed refs.FeedRef `json:"metafeed"`
	Tangles  refs.Tangles `json:"tangles"`
}

// NewAnnounceMessage returns a new Announce message.
// Callers need to set the right tangle point themselves afterwards.
func NewAnnounceMessage(f refs.FeedRef) Announce {
	return Announce{
		Type:     "metafeed/announce",
		MetaFeed: f,

		Tangles: make(refs.Tangles),
	}
}

var (
	_ bencode.Marshaler   = (*Announce)(nil)
	_ bencode.Unmarshaler = (*Announce)(nil)
)

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
