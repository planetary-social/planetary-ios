// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package multimsg

import (
	"bytes"
	"fmt"
	"io"
	"io/ioutil"

	"go.cryptoscope.co/margaret"
)

type MargaretCodec struct{}

func (c MargaretCodec) NewEncoder(w io.Writer) margaret.Encoder { return encoder{w: w} }
func (c MargaretCodec) NewDecoder(r io.Reader) margaret.Decoder { return decoder{r: r} }

func (c MargaretCodec) Marshal(v interface{}) ([]byte, error) {
	mm, ok := v.(MultiMessage)
	if !ok {
		return nil, fmt.Errorf("mmCodec: wrong type: %T", v)
	}
	return mm.MarshalBinary()
}

func (c MargaretCodec) Unmarshal(data []byte) (interface{}, error) {
	var mm MultiMessage
	err := mm.UnmarshalBinary(data)
	return &mm, err
}

type encoder struct{ w io.Writer }

func (enc encoder) Encode(v interface{}) error {
	mm, ok := v.(MultiMessage)
	if !ok {
		return fmt.Errorf("mmCodec: wrong type: %T", v)
	}
	bin, err := mm.MarshalBinary()
	if err != nil {
		return err
	}
	_, err = io.Copy(enc.w, bytes.NewReader(bin))
	return err
}

type decoder struct{ r io.Reader }

func (dec decoder) Decode() (interface{}, error) {
	bin, err := ioutil.ReadAll(io.LimitReader(dec.r, 64*1024))
	if err != nil {
		return nil, err
	}
	var mm MultiMessage
	if err := mm.UnmarshalBinary(bin); err != nil {
		return nil, err
	}
	return &mm, nil
}
