// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package private

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.mindeco.de/encodedTime"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/private/box"
	refs "go.mindeco.de/ssb-refs"
)

type unboxedLog struct {
	root, seqlog margaret.Log
	kp           ssb.KeyPair
	boxer        *box.Boxer
}

// NewUnboxerLog expects the sequence numbers, that are returned from seqlog, to be decryptable by kp.
func NewUnboxerLog(root, seqlog margaret.Log, kp ssb.KeyPair) margaret.Log {
	il := unboxedLog{
		root:   root,
		seqlog: seqlog,
		kp:     kp,
		boxer:  box.NewBoxer(nil),
	}
	return il
}

func (il unboxedLog) Changes() luigi.Observable {
	return il.seqlog.Changes()
}

func (il unboxedLog) Seq() int64 {
	return il.seqlog.Seq()
}

func (il unboxedLog) Get(seq int64) (interface{}, error) {
	v, err := il.seqlog.Get(seq)
	if err != nil {
		return nil, fmt.Errorf("seqlog: 1st lookup failed: %w", err)
	}

	rv, err := il.indirectFunc(context.TODO(), v)
	if err != nil {
		return nil, fmt.Errorf("seqlog: fetch-then-decrypt failed: %w", err)
	}
	return rv, nil
}

// Query maps the sequence values in seqlog to an unboxed version of the message
func (il unboxedLog) Query(args ...margaret.QuerySpec) (luigi.Source, error) {
	src, err := il.seqlog.Query(args...)
	if err != nil {
		return nil, fmt.Errorf("unboxLog: error querying seqlog: %w", err)
	}

	return mfr.SourceMap(src, il.indirectFunc), nil
}

func (il unboxedLog) indirectFunc(ctx context.Context, iv interface{}) (interface{}, error) {
	var rootSeq int64
	var wrappedSeq margaret.Seqer
	switch tv := iv.(type) {
	case int64:
		rootSeq = tv
	case margaret.SeqWrapper:
		wrappedSeq = tv

		wrappedVal := tv.Value()
		seq, ok := wrappedVal.(int64)
		if !ok {
			fmt.Errorf("expected sequence type: %T", wrappedVal)
		}
		rootSeq = seq
	default:
		return nil, fmt.Errorf("expected sequence type: %T", iv)
	}

	val, err := il.root.Get(rootSeq)
	if err != nil {
		return nil, fmt.Errorf("unboxLog: error getting v(%v) from seqlog log: %w", iv, err)
	}

	amsg, ok := val.(refs.Message)
	if !ok {
		return nil, fmt.Errorf("wrong message type. expected %T - got %T", amsg, val)
	}

	author := amsg.Author()

	var boxedContent []byte
	switch author.Algo() {
	case refs.RefAlgoFeedSSB1:
		input := amsg.ContentBytes()
		if !(input[0] == '"' && input[len(input)-1] == '"') {
			return nil, fmt.Errorf("expected json string with quotes")
		}
		b64data := bytes.TrimSuffix(input[1:], []byte(".box\""))
		boxedData := make([]byte, len(b64data))

		n, err := base64.StdEncoding.Decode(boxedData, b64data)
		if err != nil {
			return nil, fmt.Errorf("decode pm: invalid b64 encoding: %w", err)
		}
		boxedContent = boxedData[:n]

	case refs.RefAlgoFeedGabby:
		boxedContent = bytes.TrimPrefix(amsg.ContentBytes(), []byte("box1:"))

	default:
		return nil, fmt.Errorf("decode pm: unknown feed type: %s", author.Algo())
	}

	clearContent, err := il.boxer.Decrypt(il.kp, boxedContent)
	if err != nil {
		return nil, fmt.Errorf("unboxLog: unbox failed: %w", err)
	}

	var msg refs.KeyValueRaw
	msg.Key_ = amsg.Key()
	msg.Timestamp = encodedTime.Millisecs(amsg.Received())
	msg.Value.Previous = amsg.Previous()
	msg.Value.Author = author
	msg.Value.Sequence = amsg.Seq()
	msg.Value.Timestamp = encodedTime.Millisecs(amsg.Claimed())
	msg.Value.Hash = "go-ssb-unboxed"
	msg.Value.Content = clearContent
	msg.Value.Signature = "go-ssb-unboxed"

	if wrappedSeq != nil {
		return margaret.WrapWithSeq(msg, wrappedSeq.Seq()), nil
	}

	return msg, nil

}

// Append doesn't work on this log. They need to go through the proper channels.
func (il unboxedLog) Append(interface{}) (int64, error) {
	return -2, errors.New("can't append to seqloged log, sorry")
}
