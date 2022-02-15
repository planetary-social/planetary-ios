package gabbygrove

import (
	"fmt"

	"github.com/pkg/errors"
	"github.com/ugorji/go/codec"
	"go.cryptoscope.co/ssb"
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
	fr *ssb.FeedRef
	mr *ssb.MessageRef
	cr *ssb.ContentRef // payload/content ref
}

// currently all references are 32bytes long
// one additional byte for tagging the type
const binrefSize = 33

func (ref BinaryRef) valid() (RefType, error) {
	i := 0
	var t RefType = RefTypeUndefined
	if ref.fr != nil {
		i++
		t = RefTypeFeed
	}
	if ref.mr != nil {
		i++
		t = RefTypeMessage
	}
	if ref.cr != nil {
		i++
		t = RefTypeContent
	}
	if i > 1 {
		return RefTypeUndefined, fmt.Errorf("more than one ref in binref")
	}
	return t, nil
}

func (ref BinaryRef) Ref() string {
	t, err := ref.valid()
	if err != nil {
		panic(err)
	}
	r, err := ref.GetRef(t)
	if err != nil {
		panic(err)
	}
	return r.Ref()
}

func (ref BinaryRef) MarshalBinary() ([]byte, error) {
	t, err := ref.valid()
	if err != nil {
		return nil, err
	}
	switch t {
	case RefTypeFeed:
		return append([]byte{0x01}, ref.fr.ID...), nil
	case RefTypeMessage:
		return append([]byte{0x02}, ref.mr.Hash...), nil
	case RefTypeContent:
		if ref.cr.Algo != ssb.RefAlgoContentGabby {
			return nil, errors.Errorf("invalid binary content ref for feed: %s", ref.cr.Algo)
		}
		crBytes, err := ref.cr.MarshalBinary()
		return append([]byte{0x03}, crBytes[1:]...), err
	default:
		// TODO: check if nil!?
		return nil, nil
	}
}

func (ref *BinaryRef) UnmarshalBinary(data []byte) error {
	if n := len(data); n != binrefSize {
		return errors.Errorf("binref: invalid len:%d", n)
	}
	switch data[0] {
	case 0x01:
		ref.fr = &ssb.FeedRef{
			ID:   data[1:],
			Algo: ssb.RefAlgoFeedGabby,
		}
	case 0x02:
		ref.mr = &ssb.MessageRef{
			Hash: data[1:],
			Algo: ssb.RefAlgoMessageGabby,
		}
	case 0x03:
		var newCR ssb.ContentRef
		if err := newCR.UnmarshalBinary(append([]byte{0x02}, data[1:]...)); err != nil {
			return err
		}
		if newCR.Algo != ssb.RefAlgoContentGabby {
			return errors.Errorf("unmarshal: invalid binary content ref for feed: %q", newCR.Algo)
		}
		ref.cr = &newCR
	default:
		return fmt.Errorf("unmarshal: invalid binref type: %x", data[0])
	}
	return nil
}

func (ref *BinaryRef) Size() int {
	return binrefSize
}

func (ref BinaryRef) MarshalJSON() ([]byte, error) {
	if ref.fr != nil {
		return bytestr(ref.fr), nil
	}
	if ref.mr != nil {
		return bytestr(ref.mr), nil
	}
	if ref.cr != nil {
		return bytestr(ref.cr), nil
	}
	return nil, fmt.Errorf("should not all be nil")
}

func bytestr(r ssb.Ref) []byte {
	return []byte("\"" + r.Ref() + "\"")
}

func (ref *BinaryRef) UnmarshalJSON(data []byte) error {
	// spew.Dump(string(data))
	return errors.Errorf("TODO:json")
}

func (ref BinaryRef) GetRef(t RefType) (ssb.Ref, error) {
	hasT, err := ref.valid()
	if err != nil {
		return nil, errors.Wrap(err, "GetRef: invalid reference")
	}
	if hasT != t {
		return nil, errors.Errorf("GetRef: asked for type differs (has %d)", hasT)
	}
	// we could straight up return what is stored
	// but then we still have to assert afterwards if it really is what we want
	var ret ssb.Ref
	switch t {
	case RefTypeFeed:
		ret = ref.fr
	case RefTypeMessage:
		ret = ref.mr
	case RefTypeContent:
		ret = ref.cr
	default:
		return nil, fmt.Errorf("GetRef: invalid ref type: %d", t)
	}
	return ret, nil
}

func NewBinaryRef(r ssb.Ref) (*BinaryRef, error) {
	return fromRef(r)
}

func fromRef(r ssb.Ref) (*BinaryRef, error) {
	var br BinaryRef
	switch tr := r.(type) {
	case *ssb.FeedRef:
		br.fr = tr
	case *ssb.MessageRef:
		br.mr = tr
	case *ssb.ContentRef:
		br.cr = tr
	default:
		return nil, fmt.Errorf("fromRef: invalid ref type: %T", r)
	}
	return &br, nil
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
