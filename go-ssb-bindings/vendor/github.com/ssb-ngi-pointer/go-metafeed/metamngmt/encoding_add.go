// SPDX-License-Identifier: MIT

package metamngmt

import (
	"fmt"

	"github.com/zeebo/bencode"

	"github.com/ssb-ngi-pointer/go-metafeed/internal/bencodeext"
	"go.mindeco.de/ssb-refs/tfk"
)

type wrappedAdd struct {
	Type        bencodeext.String `bencode:"type"`
	FeedPurpose bencodeext.String `bencode:"feedpurpose"`

	SubFeed  []byte `bencode:"subfeed"`
	MetaFeed []byte `bencode:"metafeed"`

	Nonce []byte `bencode:"nonce"`

	Tangles bencodeext.Tangles `bencode:"tangles"`
}

// MarshalBencode turns an add Message into bencode bytes,
// using the bencode extenstions to cleanly seperate different types of string data
func (a Add) MarshalBencode() ([]byte, error) {
	// create TFK values for sub- and meta-feed
	subFeedTFK, err := tfk.FeedFromRef(a.SubFeed)
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to turn subfeed into tfk: %w", err)
	}
	sfBytes, err := subFeedTFK.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to encode tfk subfeed: %w", err)
	}

	metaFeedTFK, err := tfk.FeedFromRef(a.MetaFeed)
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to turn metafeed into tfk: %w", err)
	}
	mfBytes, err := metaFeedTFK.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to encode tfk metafeed: %w", err)
	}

	// now create a map of all the values and let the bencode lib sort it
	var value = wrappedAdd{
		Type:        bencodeext.String(a.Type),
		FeedPurpose: bencodeext.String(a.FeedPurpose),
		SubFeed:     sfBytes,
		MetaFeed:    mfBytes,
		Nonce:       a.Nonce,
		Tangles:     tanglesToBencoded(a.Tangles),
	}

	return bencode.EncodeBytes(value)
}

// UnmarshalBencode unpacks and validates all the bencode data that describe an Add message
func (a *Add) UnmarshalBencode(input []byte) error {
	var wa wrappedAdd
	err := bencode.DecodeBytes(input, &wa)
	if err != nil {
		return fmt.Errorf("metamgngmt/add: failed to unwrap bencode value: %w", err)
	}

	var subFeed, metaFeed tfk.Feed

	err = subFeed.UnmarshalBinary(wa.SubFeed)
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to decode tfk subfeed: %w", err)
	}

	err = metaFeed.UnmarshalBinary(wa.MetaFeed)
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to decode tfk metafeed: %w", err)
	}

	a.Type = string(wa.Type)

	if a.Type != "metafeed/add" {
		return fmt.Errorf("metafeed/add: invalid message type: %s", a.Type)
	}

	a.FeedPurpose = string(wa.FeedPurpose)

	a.SubFeed, err = subFeed.Feed()
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to turn metafeed tfk into feed: %w", err)
	}

	a.MetaFeed, err = metaFeed.Feed()
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to turn subfeed tfk into feed: %w", err)
	}

	a.Nonce = wa.Nonce

	a.Tangles = bencodedToRefTangles(wa.Tangles)

	return nil
}
