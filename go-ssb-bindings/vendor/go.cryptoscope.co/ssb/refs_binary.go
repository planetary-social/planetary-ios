// SPDX-License-Identifier: MIT

package ssb

import (
	"fmt"

	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
)

type StorageRefType byte

// enum of StorageRefTypes
const (
	StorageRefUndefined StorageRefType = iota
	StorageRefFeedLegacy
	StorageRefFeedGabby
	StorageRefMessageLegacy
	StorageRefMessageGabby
	StorageRefBlob
)

// StorageRef is used as an compact internal storage representation
type StorageRef struct {
	fr *FeedRef
	mr *MessageRef
	br *BlobRef
}

var _ Ref = (*StorageRef)(nil)

// currently all references are 32bytes long
// one additonal byte for tagging the type
const binrefSize = 33

func (ref StorageRef) valid() (StorageRefType, error) {
	i := 0
	var t StorageRefType = StorageRefUndefined
	if ref.fr != nil {
		i++
		switch ref.fr.Algo {
		case RefAlgoFeedSSB1:
			t = StorageRefFeedLegacy
		case RefAlgoFeedGabby:
			t = StorageRefFeedGabby
		default:
			return StorageRefUndefined, ErrInvalidRef
		}
	}
	if ref.mr != nil {
		i++
		switch ref.mr.Algo {
		case RefAlgoMessageSSB1:
			t = StorageRefMessageLegacy
		case RefAlgoFeedGabby:
			t = StorageRefMessageGabby
		default:
			return StorageRefUndefined, ErrInvalidRef
		}
	}
	if ref.br != nil {
		i++
		t = StorageRefBlob
	}
	if i > 1 {
		return StorageRefUndefined, errors.Errorf("more than one ref in binref")
	}
	return t, nil
}

func (ref StorageRef) String() string {
	return "storedRef:" + ref.Ref()
}

func (ref StorageRef) getRef() Ref {
	t, err := ref.valid()
	if err != nil {
		panic(err)
	}
	r, err := ref.GetRef(t)
	if err != nil {
		panic(err)
	}
	return r
}
func (ref StorageRef) Ref() string {
	return ref.getRef().Ref()
}

func (ref StorageRef) ShortRef() string {
	return ref.getRef().ShortRef()
}

func (ref StorageRef) FeedRef() (*FeedRef, error) {
	t, err := ref.valid()
	if err != nil {
		return nil, err
	}
	if t != StorageRefFeedGabby && t != StorageRefFeedLegacy && ref.fr == nil {
		return nil, errors.Errorf("not a feed refernece %d %v", t, ref.fr)
	}
	return ref.fr, nil
}

func (ref StorageRef) StoredAddr() librarian.Addr {
	b, err := ref.Marshal()
	if err != nil {
		panic(err)
	}
	return librarian.Addr(b)
}

func (ref StorageRef) Marshal() ([]byte, error) {
	b := make([]byte, binrefSize)
	n, err := ref.MarshalTo(b)
	b = b[:n]
	return b, err
}

func (ref *StorageRef) MarshalTo(data []byte) (n int, err error) {
	t, err := ref.valid()
	if err != nil {
		return 0, err
	}
	switch t {
	case StorageRefFeedLegacy:
		copy(data, append([]byte{0x01}, ref.fr.ID...))
	case StorageRefFeedGabby:
		copy(data, append([]byte{0x02}, ref.fr.ID...))
	case StorageRefMessageLegacy:
		copy(data, append([]byte{0x03}, ref.mr.Hash...))
	case StorageRefMessageGabby:
		copy(data, append([]byte{0x04}, ref.mr.Hash...))
	case StorageRefBlob:
		copy(data, append([]byte{0x05}, ref.br.Hash...))
	default:
		return 0, errors.Wrapf(ErrInvalidRefType, "invalid binref type: %x", t)
	}
	return binrefSize, nil
}

func (ref *StorageRef) Unmarshal(data []byte) error {
	if n := len(data); n != binrefSize {
		return ErrRefLen{algo: "unknown", n: n}
	}
	switch data[0] {
	case 0x01:
		ref.fr = &FeedRef{
			ID:   data[1:],
			Algo: RefAlgoFeedSSB1,
		}
	case 0x02:
		ref.fr = &FeedRef{
			ID:   data[1:],
			Algo: RefAlgoFeedGabby,
		}
	case 0x03:
		ref.mr = &MessageRef{
			Hash: data[1:],
			Algo: RefAlgoMessageSSB1,
		}
	case 0x04:
		ref.mr = &MessageRef{
			Hash: data[1:],
			Algo: RefAlgoFeedGabby,
		}
	case 0x05:
		ref.br = &BlobRef{
			Hash: data[1:],
			Algo: RefAlgoBlobSSB1,
		}

	default:
		return errors.Wrapf(ErrInvalidRefType, "invalid binref type: %x", data[0])
	}
	return nil
}

func (ref StorageRef) MarshalJSON() ([]byte, error) {
	if ref.fr != nil {
		return bytestr(ref.fr), nil
	}
	if ref.mr != nil {
		return bytestr(ref.mr), nil
	}
	if ref.br != nil {
		return bytestr(ref.br), nil
	}
	return nil, fmt.Errorf("should not all be nil")
}

func bytestr(r Ref) []byte {
	return []byte("\"" + r.Ref() + "\"")
}

func (ref *StorageRef) UnmarshalJSON(data []byte) error {
	return errors.Errorf("TODO:json")
}

func (ref StorageRef) GetRef(t StorageRefType) (Ref, error) {
	hasT, err := ref.valid()
	if err != nil {
		return nil, errors.Wrap(err, "GetRef: invalid reference")
	}
	if hasT != t {
		return nil, errors.Errorf("GetRef: asked for type differs (has %d)", hasT)
	}
	// we could straight up return what is stored
	// but then we still have to assert afterwards if it really is what we want
	var ret Ref
	switch t {
	case StorageRefFeedLegacy, StorageRefFeedGabby:
		ret = ref.fr
	case StorageRefMessageLegacy, StorageRefMessageGabby:
		ret = ref.mr
	case StorageRefBlob:
		ret = ref.br
	default:
		return nil, errors.Wrapf(ErrInvalidRefType, "invalid binref type: %x", t)
	}
	return ret, nil
}

func NewStorageRefFromString(s string) (*StorageRef, error) {
	r, err := ParseRef(s)
	if err != nil {
		return nil, errors.Wrap(err, "binref: not a ssb ref")
	}
	return NewStorageRef(r)
}

func NewStorageRef(r Ref) (*StorageRef, error) {
	var br StorageRef
	switch tr := r.(type) {
	case FeedRef:
		br.fr = &tr
	case *FeedRef:
		br.fr = tr
	case *MessageRef:
		br.mr = tr
	case *BlobRef:
		br.br = tr
	default:
		return nil, errors.Wrapf(ErrInvalidRefType, "invalid binref type (%T)", r)
	}
	return &br, nil
}
