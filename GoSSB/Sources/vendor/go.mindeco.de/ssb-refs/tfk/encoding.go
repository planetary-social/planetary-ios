package tfk

import (
	"fmt"

	refs "go.mindeco.de/ssb-refs"
)

// Encode returns type-format-key bytes for supported references.
// Currently only *refs.MessageRef and *refs.FeedRef
func Encode(r refs.Ref) ([]byte, error) {
	switch tv := r.(type) {

	case refs.MessageRef:
		m, err := MessageFromRef(tv)
		if err != nil {
			return nil, err
		}
		return m.MarshalBinary()

	case refs.FeedRef:
		f, err := FeedFromRef(tv)
		if err != nil {
			return nil, err
		}
		return f.MarshalBinary()

	default:
		return nil, fmt.Errorf("ssb/tfk: unhandled reference type")
	}
}
