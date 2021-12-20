// Package tfk implements the type-format-key encoding for SSB references.
//
// See https://github.com/ssbc/envelope-spec/ ... encoding/tfk.md
package tfk

import "errors"

// Type are the type-format-key type values
const (
	TypeFeed uint8 = iota
	TypeMessage
	TypeBlob
	TypeDiffieHellmanKey
)

// These are the type-format-key feed format values
const (
	FormatFeedEd25519 uint8 = iota
	FormatFeedGabbyGrove
	FormatFeedBamboo
	FormatFeedBendyButt
	FormatFeedFusionIdentity
)

// IsValidFeedFormat returns true if the passed format is a valid feed format
func IsValidFeedFormat(f uint8) bool {
	return f <= FormatFeedFusionIdentity
}

// These are the type-format-key message format values
const (
	FormatMessageSHA256 uint8 = iota
	FormatMessageGabbyGrove
	FormatMessageCloaked
	FormatMessageBamboo
	FormatMessageMetaFeed
)

// IsValidMessageFormat returns true if the passed format is a valid message format
func IsValidMessageFormat(f uint8) bool {
	return f <= FormatMessageMetaFeed
}

// Common errors
var (
	ErrTooShort        = errors.New("ssb/tfk: data too short")
	ErrWrongType       = errors.New("ssb/tfk: unexpected type value")
	ErrUnhandledFormat = errors.New("ssb/tfk: unhandled format value")
)
