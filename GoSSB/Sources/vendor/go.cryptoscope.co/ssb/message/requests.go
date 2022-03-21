// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package message

import (
	"bytes"
	"encoding/json"
	"fmt"

	refs "go.mindeco.de/ssb-refs"
)

type WhoamiReply struct {
	ID refs.FeedRef `json:"id"`
}

type CommonArgs struct {
	Keys   bool `json:"keys"` // can't omit this falsy value, the JS-stack stack assumes true if it's not there
	Values bool `json:"values,omitempty"`
	Live   bool `json:"live,omitempty"`

	Private bool `json:"private,omitempty"`
}

type StreamArgs struct {
	Limit int64 `json:"limit,omitempty"`

	Gt RoundedInteger `json:"gt,omitempty"`
	Lt RoundedInteger `json:"lt,omitempty"`

	Reverse bool `json:"reverse,omitempty"`
}

func NewStreamArgs() StreamArgs {
	return StreamArgs{
		Limit: -1,
	}
}

// CreateHistArgs defines the query parameters for the createHistoryStream rpc call
type CreateHistArgs struct {
	CommonArgs
	StreamArgs

	ID  refs.FeedRef `json:"id,omitempty"`
	Seq int64        `json:"seq,omitempty"`

	AsJSON bool `json:"asJSON,omitempty"`
}

func NewCreateHistoryStreamArgs() CreateHistArgs {
	return CreateHistArgs{
		StreamArgs: NewStreamArgs(),
	}
}

// CreateLogArgs defines the query parameters for the createLogStream rpc call
type CreateLogArgs struct {
	CommonArgs
	StreamArgs

	Seq int64 `json:"seq"`
}

// MessagesByTypeArgs defines the query parameters for the messagesByType rpc call
type MessagesByTypeArgs struct {
	CommonArgs
	StreamArgs

	Type string `json:"type"`
}

type TanglesArgs struct {
	CommonArgs
	StreamArgs

	Root refs.MessageRef `json:"root"`

	// indicate the v2 subtangle (group, ...)
	// empty string for v1 tangle
	Name string `json:"name"`
}

// RoundedInteger also accepts unmarshaling from a float
type RoundedInteger int64

func (ri *RoundedInteger) UnmarshalJSON(input []byte) error {
	var isFloat = false
	if idx := bytes.Index(input, []byte(".")); idx > 0 {
		input = input[:idx]
		isFloat = true
	}

	var i int64
	err := json.Unmarshal(input, &i)
	if err != nil {
		return fmt.Errorf("RoundedInteger: input is not an int: %w", err)
	}

	*ri = RoundedInteger(i)
	if isFloat {
		*ri++
	}

	return nil
}
