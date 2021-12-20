package metamngmt

import (
	"github.com/ssb-ngi-pointer/go-metafeed/internal/bencodeext"
	"github.com/zeebo/bencode"
)

// UnmarshalBencode unpacks bencode extended data into an Typed message.
func (t *Typed) UnmarshalBencode(input []byte) error {
	var wt wrappedTyped
	err := bencode.DecodeBytes(input, &wt)
	if err != nil {
		return err
	}
	t.Type = string(wt.Type)
	return nil
}

type wrappedTyped struct {
	Type bencodeext.String `bencode:"type"`
}
