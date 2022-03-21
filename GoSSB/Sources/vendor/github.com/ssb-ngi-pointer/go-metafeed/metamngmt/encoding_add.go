// SPDX-FileCopyrightText: 2021 The go-metafeed Authors
//
// SPDX-License-Identifier: MIT

package metamngmt

import (
	"fmt"

	"github.com/zeebo/bencode"

	"github.com/ssb-ngi-pointer/go-metafeed/internal/bencodeext"
	"go.mindeco.de/ssb-refs/tfk"
)

type wrappedAddDerived struct {
	Type        bencodeext.String `bencode:"type"`
	FeedPurpose bencodeext.String `bencode:"feedpurpose"`

	SubFeed  []byte `bencode:"subfeed"`
	MetaFeed []byte `bencode:"metafeed"`

	Nonce bencodeext.Bytes `bencode:"nonce"`

	Tangles bencodeext.Tangles `bencode:"tangles"`

	QueryLang bencodeext.String `bencode:"querylang,omitempty"`
	Query     bencodeext.String `bencode:"query,omitempty"`
}

// MarshalBencode turns an add Message into bencode bytes,
// using the bencode extenstions to cleanly seperate different types of string data
func (derived AddDerived) MarshalBencode() ([]byte, error) {
	// create TFK values for sub- and meta-feed
	subFeedTFK, err := tfk.FeedFromRef(derived.SubFeed)
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to turn subfeed into tfk: %w", err)
	}
	sfBytes, err := subFeedTFK.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to encode tfk subfeed: %w", err)
	}

	metaFeedTFK, err := tfk.FeedFromRef(derived.MetaFeed)
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to turn metafeed into tfk: %w", err)
	}
	mfBytes, err := metaFeedTFK.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("metafeed/add: failed to encode tfk metafeed: %w", err)
	}

	// now create a map of all the values and let the bencode lib sort it
	var value = wrappedAddDerived{
		Type:        bencodeext.String(typeAddDerived),
		FeedPurpose: bencodeext.String(derived.FeedPurpose),
		SubFeed:     sfBytes,
		MetaFeed:    mfBytes,
		Nonce:       bencodeext.Bytes(derived.Nonce),
		Tangles:     tanglesToBencoded(derived.Tangles),
	}

	// add optional values
	if val, has := derived.GetMetadata("querylang"); has {
		value.QueryLang = bencodeext.String(val)
	}

	if val, has := derived.GetMetadata("query"); has {
		value.Query = bencodeext.String(val)
	}

	return bencode.EncodeBytes(value)
}

// UnmarshalBencode unpacks and validates all the bencode data that describe an Add message
func (a *AddDerived) UnmarshalBencode(input []byte) error {
	var wa wrappedAddDerived
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

	msgType := string(wa.Type)
	if msgType != typeAddDerived {
		return fmt.Errorf("metafeed/add: invalid message type: %s", msgType)
	}
	a.Type = msgType

	a.FeedPurpose = string(wa.FeedPurpose)
	err = a.InsertMetadata(map[string]string{
		"querylang": string(wa.QueryLang),
		"query":     string(wa.Query),
	})
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to insert query metadata into message: %w", err)
	}

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

type wrappedAddExisting struct {
	Type        bencodeext.String `bencode:"type"`
	FeedPurpose bencodeext.String `bencode:"feedpurpose"`

	SubFeed  []byte `bencode:"subfeed"`
	MetaFeed []byte `bencode:"metafeed"`

	Tangles bencodeext.Tangles `bencode:"tangles"`
}

// MarshalBencode turns an add Message into bencode bytes,
// using the bencode extenstions to cleanly seperate different types of string data
func (a AddExisting) MarshalBencode() ([]byte, error) {
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
	var value = wrappedAddExisting{
		Type:        bencodeext.String(typeAddExisting),
		FeedPurpose: bencodeext.String(a.FeedPurpose),
		SubFeed:     sfBytes,
		MetaFeed:    mfBytes,
		Tangles:     tanglesToBencoded(a.Tangles),
	}

	return bencode.EncodeBytes(value)
}

// UnmarshalBencode unpacks and validates all the bencode data that describe an Add message
func (a *AddExisting) UnmarshalBencode(input []byte) error {
	var wa wrappedAddExisting
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

	msgType := string(wa.Type)
	if msgType != typeAddExisting {
		return fmt.Errorf("metafeed/add: invalid message type: %s", msgType)
	}
	a.Type = msgType

	a.FeedPurpose = string(wa.FeedPurpose)

	a.SubFeed, err = subFeed.Feed()
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to turn metafeed tfk into feed: %w", err)
	}

	a.MetaFeed, err = metaFeed.Feed()
	if err != nil {
		return fmt.Errorf("metafeed/add: failed to turn subfeed tfk into feed: %w", err)
	}

	a.Tangles = bencodedToRefTangles(wa.Tangles)

	return nil
}
