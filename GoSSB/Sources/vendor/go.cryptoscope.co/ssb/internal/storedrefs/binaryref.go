// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package storedrefs

import (
	"fmt"

	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

type SerialzedFeed struct {
	refs.FeedRef
}

func (sf SerialzedFeed) MarshalBinary() ([]byte, error) {
	return tfk.Encode(sf.FeedRef)
}

func (sf *SerialzedFeed) UnmarshalBinary(input []byte) error {
	var f tfk.Feed
	err := f.UnmarshalBinary(input)
	if err != nil {
		return fmt.Errorf("serializedFeed: failed to parse tfk data: %w", err)
	}

	fr, err := f.Feed()
	if err != nil {
		return fmt.Errorf("serializedFeed: failed turn tfk data into feed ref: %w", err)
	}

	sf.FeedRef = fr
	return nil
}

type SerialzedMessage struct {
	refs.MessageRef
}

func (sm SerialzedMessage) MarshalBinary() ([]byte, error) {
	return tfk.Encode(sm.MessageRef)
}

func (sm *SerialzedMessage) UnmarshalBinary(input []byte) error {
	var f tfk.Message
	err := f.UnmarshalBinary(input)
	if err != nil {
		return fmt.Errorf("serializedMessage: failed to parse tfk data: %w", err)
	}

	mr, err := f.Message()
	if err != nil {
		return fmt.Errorf("serializedMessage: failed turn tfk data into message ref: %w", err)
	}

	sm.MessageRef = mr
	return nil
}
