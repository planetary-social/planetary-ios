package gabbygrove

import (
	"fmt"

	"github.com/pkg/errors"
	"github.com/ugorji/go/codec"
	"golang.org/x/crypto/ed25519"

	refs "go.mindeco.de/ssb-refs"
)

type RefType uint

const (
	RefTypeUndefined RefType = iota
	RefTypeFeed
	RefTypeMessage
	RefTypeContent
)

// BinaryRef defines a binary representation for feed, message, and content references
type BinaryRef struct {
	r refs.Ref
}

// currently all references are 32bytes long
// one additional byte for tagging the type
const binrefSize = 33

func (ref BinaryRef) valid() (RefType, error) {
	switch tv := ref.r.(type) {
	case refs.FeedRef:
		return RefTypeFeed, nil
	case refs.MessageRef:
		return RefTypeMessage, nil
	case ContentRef:
		return RefTypeContent, nil
	default:
		return RefTypeUndefined, fmt.Errorf("unhandled binary ref: %T", tv)
	}
}

func (ref BinaryRef) Sigil() string {
	t, err := ref.valid()
	if err != nil {
		panic(err)
	}
	r, err := ref.GetRef(t)
	if err != nil {
		panic(err)
	}
	return r.Sigil()
}

func (ref BinaryRef) URI() string {
	return ref.r.URI()
}

func (ref BinaryRef) MarshalBinary() ([]byte, error) {
	t, err := ref.valid()
	if err != nil {
		return nil, nil
	}
	switch t {
	case RefTypeFeed:
		return append([]byte{0x01}, ref.r.(refs.FeedRef).PubKey()...), nil
	case RefTypeMessage:
		hd := make([]byte, 32)
		err := ref.r.(refs.MessageRef).CopyHashTo(hd)
		return append([]byte{0x02}, hd...), err
	case RefTypeContent:
		if ref.r.Algo() != RefAlgoContentGabby {
			return nil, errors.Errorf("invalid binary content ref for feed: %s", ref.r.Algo())
		}
		crBytes, err := ref.r.(ContentRef).MarshalBinary()
		return append([]byte{0x03}, crBytes[1:]...), err
	default:
		return nil, fmt.Errorf("unhandled binary ref: %d", t)
	}
}

func (ref *BinaryRef) UnmarshalBinary(data []byte) error {
	if n := len(data); n != binrefSize {
		return errors.Errorf("binref: invalid len:%d", n)
	}
	switch data[0] {
	case 0x01:
		fr, err := refs.NewFeedRefFromBytes(data[1:], refs.RefAlgoFeedGabby)
		if err != nil {
			return err
		}
		ref.r = fr
	case 0x02:
		mr, err := refs.NewMessageRefFromBytes(data[1:], refs.RefAlgoMessageGabby)
		if err != nil {
			return err
		}
		ref.r = mr
	case 0x03:
		var newCR ContentRef
		if err := newCR.UnmarshalBinary(append([]byte{0x02}, data[1:]...)); err != nil {
			return err
		}
		if newCR.Algo() != RefAlgoContentGabby {
			return errors.Errorf("unmarshal: invalid binary content ref for feed: %q", newCR.algo)
		}
		ref.r = newCR
	default:
		return fmt.Errorf("unmarshal: invalid binref type: %x", data[0])
	}
	return nil
}

func (ref *BinaryRef) Size() int {
	return binrefSize
}

func (ref BinaryRef) MarshalText() ([]byte, error) {
	return ref.r.MarshalText()
}

func (ref BinaryRef) MarshalJSON() ([]byte, error) {
	return bytestr(ref.r), nil
}

func bytestr(r refs.Ref) []byte {
	return []byte("\"" + r.URI() + "\"")
}

func (ref *BinaryRef) UnmarshalText(data []byte) error {
	return errors.Errorf("TODO:text")
}

func (ref *BinaryRef) UnmarshalJSON(data []byte) error {
	return errors.Errorf("TODO:json")
}

func (ref BinaryRef) GetRef(t RefType) (refs.Ref, error) {
	hasT, err := ref.valid()
	if err != nil {
		return nil, errors.Wrap(err, "GetRef: invalid reference")
	}
	if hasT != t {
		return nil, errors.Errorf("GetRef: asked for type differs (has %d)", hasT)
	}
	return ref.r, nil
}

func NewBinaryRef(r refs.Ref) (BinaryRef, error) {
	return fromRef(r)
}

func fromRef(r refs.Ref) (BinaryRef, error) {
	var br BinaryRef
	switch tr := r.(type) {
	case refs.FeedRef:
		br.r = tr
	case refs.MessageRef:
		br.r = tr
	case ContentRef:
		br.r = tr
	default:
		return BinaryRef{}, fmt.Errorf("fromRef: invalid ref type: %T", r)
	}
	return br, nil
}

func refFromPubKey(pk ed25519.PublicKey) (BinaryRef, error) {
	if len(pk) != ed25519.PublicKeySize {
		return BinaryRef{}, fmt.Errorf("invalid public key")
	}
	fr, err := refs.NewFeedRefFromBytes(pk, refs.RefAlgoFeedGabby)
	return BinaryRef{
		r: fr,
	}, err
}

type BinRefExt struct{}

var _ codec.InterfaceExt = (*BinRefExt)(nil)

func (x BinRefExt) ConvertExt(v interface{}) interface{} {
	br, ok := v.(*BinaryRef)
	if !ok {
		panic(fmt.Sprintf("unsupported format expecting to decode into *BinaryRef; got %T", v))
	}
	refBytes, err := br.MarshalBinary()
	if err != nil {
		panic(err) //hrm...
	}
	return refBytes
}

func (x BinRefExt) UpdateExt(dst interface{}, src interface{}) {
	br, ok := dst.(*BinaryRef)
	if !ok {
		panic(fmt.Sprintf("unsupported format - expecting to decode into *BinaryRef; got %T", dst))
	}

	input, ok := src.([]byte)
	if !ok {
		panic(fmt.Sprintf("unsupported input format - expecting to decode from []byte; got %T", src))
	}

	err := br.UnmarshalBinary(input)
	if err != nil {
		panic(err)
	}

}
