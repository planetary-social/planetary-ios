// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package legacy

import (
	"encoding/json"
	"fmt"

	refs "go.mindeco.de/ssb-refs"
	"golang.org/x/crypto/ed25519"
)

// MetafeedAnnounce is the type needed to do upgrades from existing classic feeds to the metafeed world.
// https://github.com/ssb-ngi-pointer/ssb-meta-feeds-spec#existing-ssb-identity
type MetafeedAnnounce struct {
	Type     string       `json:"type"`
	Subfeed  refs.FeedRef `json:"subfeed"`
	Metafeed refs.FeedRef `json:"metafeed"`

	Tangles refs.Tangles `json:"tangles"`
}

const metafeedAnnounceType = "metafeed/announce"

// Creates a fresh MetafeedAnnounce value with all the fields initialzed properly (especially Type and Tangles)
func NewMetafeedAnnounce(theMeta, theUpgrading refs.FeedRef) MetafeedAnnounce {
	var ma MetafeedAnnounce
	ma.Type = metafeedAnnounceType

	ma.Metafeed = theMeta
	ma.Subfeed = theUpgrading

	ma.Tangles = make(refs.Tangles)
	ma.Tangles["metafeed"] = refs.TanglePoint{Root: nil, Previous: nil}
	return ma
}

// Sign takes a privarte key to create a signature on the receivers annoucement and returns the signed JSON message, ready to be published on a feed.
// it also takes an optional HMAC secret, if the network is using that signature mode.
func (ma MetafeedAnnounce) Sign(priv ed25519.PrivateKey, hmacSecret *[32]byte) (json.RawMessage, error) {
	// for compliance with JS, we need to indent and encode the message like V8 JSON.stringify would
	announcementV8Format, err := jsonAndPreserve(ma)
	if err != nil {
		return nil, fmt.Errorf("legacySign: error during sign prepare: %w", err)
	}

	announcementV8Format = maybeHMAC(announcementV8Format, hmacSecret)

	// compute the signature
	sig := ed25519.Sign(priv, announcementV8Format)

	// attach the signature
	var signedMsg signedMetafeedAnnouncment
	signedMsg.MetafeedAnnounce = ma
	signedMsg.Signature = sig

	return json.Marshal(signedMsg)
}

// signedMetafeedAnnouncment wrapps a MetafeedAnnounce with a Signature
type signedMetafeedAnnouncment struct {
	MetafeedAnnounce

	Signature Signature `json:"signature"`
}

// VerifyMetafeedAnnounce takes a raw json body and asserts the validity of the signature and that it is for the right feed.
func VerifyMetafeedAnnounce(data []byte, subfeedAuthor refs.FeedRef, hmacSecret *[32]byte) (MetafeedAnnounce, bool) {
	// json decode for validty of the fields and easily access the values
	var signedAnnouncement signedMetafeedAnnouncment
	err := json.Unmarshal(data, &signedAnnouncement)
	if err != nil {
		return MetafeedAnnounce{}, false
	}

	// make sure it has the right type value
	if signedAnnouncement.Type != metafeedAnnounceType {
		return MetafeedAnnounce{}, false
	}

	// make sure the subfeed in the message is for the right author
	// to protect against replays on other feeds
	if !signedAnnouncement.Subfeed.Equal(subfeedAuthor) {
		return MetafeedAnnounce{}, false
	}

	// turn the data as is into JSON.stringify()-like form
	v8indented, err := PrettyPrint(data)
	if err != nil {
		return MetafeedAnnounce{}, false
	}

	// to check the signature we need it to split it into message and signature
	msg, _, err := ExtractSignature(v8indented)
	if err != nil {
		return MetafeedAnnounce{}, false
	}

	msg = maybeHMAC(msg, hmacSecret)

	err = signedAnnouncement.Signature.Verify(msg, signedAnnouncement.Metafeed)
	if err != nil {
		return MetafeedAnnounce{}, false
	}

	// return just the announcment part
	return signedAnnouncement.MetafeedAnnounce, true
}
