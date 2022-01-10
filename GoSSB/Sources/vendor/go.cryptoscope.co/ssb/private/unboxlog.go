// SPDX-License-Identifier: MIT

package private

import (
	"bytes"
	"context"
	"encoding/base64"

	"github.com/cryptix/go/encodedTime"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb"
)

type unboxedLog struct {
	root, seqlog margaret.Log
	kp           *ssb.KeyPair
}

// NewUnboxerLog expects the sequence numbers, that are returned from seqlog, to be decryptable by kp.
func NewUnboxerLog(root, seqlog margaret.Log, kp *ssb.KeyPair) margaret.Log {
	il := unboxedLog{
		root:   root,
		seqlog: seqlog,
		kp:     kp,
	}
	return il
}

func (il unboxedLog) Seq() luigi.Observable {
	return il.seqlog.Seq()
}

func (il unboxedLog) Get(seq margaret.Seq) (interface{}, error) {
	return nil, errors.Errorf("TODO: unbox here too?")

	// TODO: use indirect
	v, err := il.seqlog.Get(seq)
	if err != nil {
		return nil, errors.Wrap(err, "seqlog: 1st lookup failed")
	}

	rv, err := il.root.Get(v.(margaret.Seq))
	// TODO: unbox?!?
	return rv, errors.Wrap(err, "seqlog: root lookup failed")
}

// Query maps the sequence values in seqlog to an unboxed version of the message
func (il unboxedLog) Query(args ...margaret.QuerySpec) (luigi.Source, error) {
	src, err := il.seqlog.Query(args...)
	if err != nil {
		return nil, errors.Wrap(err, "unboxLog: error querying seqlog")
	}

	return mfr.SourceMap(src, func(ctx context.Context, iv interface{}) (interface{}, error) {
		var rootSeq margaret.Seq
		var wrappedSeq margaret.Seq
		switch tv := iv.(type) {
		case margaret.Seq:
			rootSeq = tv
		case margaret.SeqWrapper:
			wrappedSeq = tv.Seq()

			wrappedVal := tv.Value()
			seq, ok := wrappedVal.(margaret.Seq)
			if !ok {
				errors.Errorf("expected sequence type: %T", wrappedVal)
			}
			rootSeq = seq
		default:
			return nil, errors.Errorf("expected sequence type: %T", iv)
		}

		val, err := il.root.Get(rootSeq)
		if err != nil {
			return nil, errors.Wrapf(err, "unboxLog: error getting v(%d) from seqlog log", rootSeq.Seq())
		}

		amsg, ok := val.(ssb.Message)
		if !ok {
			return nil, errors.Errorf("wrong message type. expected %T - got %T", amsg, val)
		}

		author := amsg.Author()

		var boxedContent []byte
		switch author.Algo {
		case ssb.RefAlgoFeedSSB1:
			input := amsg.ContentBytes()
			if !(input[0] == '"' && input[len(input)-1] == '"') {
				return nil, errors.Errorf("expected json string with quotes")
			}
			b64data := bytes.TrimSuffix(input[1:], []byte(".box\""))
			boxedData := make([]byte, len(b64data))

			n, err := base64.StdEncoding.Decode(boxedData, b64data)
			if err != nil {
				return nil, errors.Wrap(err, "decode pm: invalid b64 encoding")
			}
			boxedContent = boxedData[:n]

		case ssb.RefAlgoFeedGabby:
			boxedContent = bytes.TrimPrefix(amsg.ContentBytes(), []byte("box1:"))

		default:
			return nil, errors.Errorf("decode pm: unknown feed type: %s", author.Algo)
		}

		clearContent, err := Unbox(il.kp, boxedContent)
		if err != nil {
			return nil, errors.Wrap(err, "unboxLog: unbox failed")
		}

		var msg ssb.KeyValueRaw
		msg.Key_ = amsg.Key()
		msg.Timestamp = encodedTime.Millisecs(amsg.Received())
		msg.Value.Previous = amsg.Previous()
		msg.Value.Author = *author
		msg.Value.Sequence = margaret.BaseSeq(amsg.Seq())
		msg.Value.Timestamp = encodedTime.Millisecs(amsg.Claimed())
		msg.Value.Hash = "go-ssb-unboxed"
		msg.Value.Content = clearContent
		msg.Value.Signature = "go-ssb-unboxed"

		if wrappedSeq != nil {
			return margaret.WrapWithSeq(msg, wrappedSeq), nil
		}

		return msg, nil
	}), nil
}

// Append doesn't work on this log. They need to go through the proper channels.
func (il unboxedLog) Append(interface{}) (margaret.Seq, error) {
	return nil, errors.New("can't append to seqloged log, sorry")
}
