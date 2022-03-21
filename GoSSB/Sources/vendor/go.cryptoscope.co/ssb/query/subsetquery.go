// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package query holds the first version of a generic query engine for go-ssb.
// The Subset operations are able to combine arbitrary boolen combinations of type:xzy and author:@foo filters into one result.
package query

import (
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

// SubsetOptions defines additional options for the getSubset rpc call
type SubsetOptions struct {
	Keys       bool `json:"keys"` // can't omit this falsy value, the JS-stack stack assumes true if it's not there
	Descending bool `json:"descending,omitempty"`
	PageLimit  int  `json:"pageLimit,omitempty"`
}

// SubsetOperation encapsulates the recursive structure of operations for the QuerySubset*() methods
type SubsetOperation struct {
	operation string

	args   []SubsetOperation
	string string
	feed   *refs.FeedRef
}

// NewSubsetOpByType returns a single operation which filters messages by type
func NewSubsetOpByType(value string) SubsetOperation {
	return SubsetOperation{operation: "type", string: value}
}

// NewSubsetOpByAuthor returns a single operation which filters messages by author
func NewSubsetOpByAuthor(a refs.FeedRef) SubsetOperation {
	return SubsetOperation{operation: "author", feed: &a}
}

// NewSubsetAndCombination turns the list of passed operations into a logical combination where all of them need to apply
func NewSubsetAndCombination(ops ...SubsetOperation) SubsetOperation {
	return SubsetOperation{operation: "and", args: ops}
}

// NewSubsetOrCombination turns the list of passed operations into a logical combination where any of them needs to apply
func NewSubsetOrCombination(ops ...SubsetOperation) SubsetOperation {
	return SubsetOperation{operation: "or", args: ops}
}

// MarshalJSON turns a SubsetOperation into JSON for remote calls.
func (so SubsetOperation) MarshalJSON() ([]byte, error) {
	var m subsetOperationJSONMarshaler

	m.Operation = so.operation
	m.String = so.string
	m.Feed = so.feed
	m.Args = so.args

	return json.Marshal(m)
}

// UnmarshalJSON turns JSON into a SubsetOperation and validates it.
func (so *SubsetOperation) UnmarshalJSON(input []byte) error {
	// TODO: restrict length to something reasonable
	if n := len(input); n > 4*1024 {
		return fmt.Errorf("subset query is too long (%d)", n)
	}

	var m subsetOperationJSONMarshaler
	err := json.Unmarshal(input, &m)
	if err != nil {
		return fmt.Errorf("subset query unmarshaling failed: %w", err)
	}

	switch m.Operation {
	case "and", "or":
		so.args = m.Args
	case "type":
		so.string = m.String
	case "author":
		if m.Feed == nil {
			return fmt.Errorf("subset: author can't be empty")
		}
		if err := ssb.IsValidFeedFormat(*m.Feed); err != nil {
			return fmt.Errorf("subset: author is invalid feed format: %w", err)
		}
		so.feed = m.Feed
	default:
		return fmt.Errorf("unhandled subset operation: %q", m.Operation)
	}

	so.operation = m.Operation

	return nil
}

// a helper for converting a SubsetOperation to JSON
type subsetOperationJSONMarshaler struct {
	Operation string `json:"op"`

	Args   []SubsetOperation `json:"args,omitempty"`
	String string            `json:"string,omitempty"`
	Feed   *refs.FeedRef     `json:"feed,omitempty"`
}
