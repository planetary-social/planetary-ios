package tfk

import (
	"fmt"

	refs "go.mindeco.de/ssb-refs"
)

type Feed struct{ value }

func FeedFromRef(r refs.FeedRef) (*Feed, error) {
	var f Feed
	f.tipe = TypeFeed

	switch r.Algo() {
	case refs.RefAlgoFeedSSB1:
		f.format = FormatFeedEd25519
	case refs.RefAlgoFeedGabby:
		f.format = FormatFeedGabbyGrove
	case refs.RefAlgoFeedBamboo:
		f.format = FormatFeedBamboo
	case refs.RefAlgoFeedBendyButt:
		f.format = FormatFeedBendyButt
	default:
		return nil, fmt.Errorf("format value: %s: %w", r.Algo(), ErrUnhandledFormat)
	}

	pubKey := r.PubKey()
	if n := len(pubKey); n != 32 {
		return nil, fmt.Errorf("ssb/tfk: unexpected value length %d: %w", n, ErrTooShort)
	}

	f.key = make([]byte, 32)
	copy(f.key, pubKey)

	return &f, nil
}

// MarshalBinary returns the type-format-key encoding for a feed.
func (f *Feed) MarshalBinary() ([]byte, error) {
	if f.tipe != TypeFeed {
		return nil, ErrWrongType
	}
	if !IsValidFeedFormat(f.format) {
		return nil, ErrUnhandledFormat
	}
	if n := len(f.key); n != 32 {
		return nil, fmt.Errorf("tfk/feed: unexpected key length: %d: %w", n, ErrTooShort)
	}
	return f.value.MarshalBinary()
}

// UnmarshalBinary takes some data, unboxes the t-f-k
// and does some validity checks to make sure it's an understood feed reference.
func (f *Feed) UnmarshalBinary(data []byte) error {
	err := f.value.UnmarshalBinary(data)
	if err != nil {
		f.broken = true
		return err
	}

	if f.tipe != TypeFeed {
		f.broken = true
		return ErrWrongType
	}

	if !IsValidFeedFormat(f.format) {
		f.broken = true
		return ErrUnhandledFormat
	}

	if n := len(f.key); n != 32 {
		f.broken = true
		return fmt.Errorf("ssb/tfk/feed: unexpected key length: %d: %w", n, ErrTooShort)
	}

	return nil
}

// Feed retruns the ssb-ref type after a successfull unmarshal.
// It returns a new copy to discourage tampering with the internal values of this reference.
func (f Feed) Feed() (refs.FeedRef, error) {
	if f.broken {
		return refs.FeedRef{}, fmt.Errorf("broken feed reference")
	}
	var algo refs.RefAlgo
	switch f.format {
	case FormatFeedEd25519:
		algo = refs.RefAlgoFeedSSB1
	case FormatFeedGabbyGrove:
		algo = refs.RefAlgoFeedGabby
	case FormatFeedBamboo:
		algo = refs.RefAlgoFeedBamboo
	case FormatFeedBendyButt:
		algo = refs.RefAlgoFeedBendyButt
	default:
		return refs.FeedRef{}, fmt.Errorf("ssb/tfk/feed: invalid reference algo: %d", f.format)
	}
	return refs.NewFeedRefFromBytes(f.key, algo)
}
