// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package ssb

import (
	"encoding/json"

	"go.cryptoscope.co/margaret"
	refs "go.mindeco.de/ssb-refs"
)

// DropContentRequest has special meaning on a gabby-grove feed.
// It's signature verification allows ommiting the content.
// A feed author can ask other peers to drop a previous message of theirs with this.
// Sequence must be smaller then current, also the targeted message can't be a drop-content-request
type DropContentRequest struct {
	Type     string          `json:"type"`
	Sequence uint            `json:"sequence"`
	Hash     refs.MessageRef `json:"hash"`
}

const DropContentRequestType = "drop-content-request"

func NewDropContentRequest(seq uint, h refs.MessageRef) *DropContentRequest {
	return &DropContentRequest{
		Type:     DropContentRequestType,
		Sequence: seq,
		Hash:     h,
	}
}

func (dcr DropContentRequest) Valid(log margaret.Log) bool {
	if dcr.Sequence < 1 {
		return false
	}

	msgv, err := log.Get(int64(dcr.Sequence - 1))
	if err != nil {
		return false
	}

	msg, ok := msgv.(refs.Message)
	if !ok {
		return false
	}

	if msg.Author().Algo() != refs.RefAlgoFeedGabby {
		return false
	}

	match := msg.Key().Equal(dcr.Hash)
	if !match {
		return false
	}

	// check we can't delete deletes
	var msgType struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(msg.ContentBytes(), &msgType); err != nil {
		return false
	}
	if msgType.Type == DropContentRequestType {
		return false
	}

	return true
}
