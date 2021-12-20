// SPDX-License-Identifier: MIT

package multilogs

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"os"

	"github.com/dgraph-io/badger/v3"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog"
	multibadger "go.cryptoscope.co/margaret/multilog/roaring/badger"
	kitlog "go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message/multimsg"
	"go.cryptoscope.co/ssb/private/box"
	"go.cryptoscope.co/ssb/repo"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"
	refs "go.mindeco.de/ssb-refs"
)

const IndexNamePrivates = "privates"

/* deprecated
// not strictly a multilog but allows multiple keys and gives us the good resumption
func NewPrivateRead(log kitlog.Logger, kps ...*ssb.KeyPair) *Private {
	return &Private{
		logger:   log,
		keyPairs: kps,
		boxer:    box.NewBoxer(nil),
	}
}
*/

type Private struct {
	logger kitlog.Logger

	keyPairs []ssb.KeyPair
	boxer    *box.Boxer
}

// OpenRoaring uses roaring bitmaps with a slim key-value store backend
func (pr Private) OpenRoaring(r repo.Interface, db *badger.DB) (multilog.MultiLog, librarian.SinkIndex, error) {
	mlog, err := multibadger.NewShared(db, []byte(IndexNamePrivates))
	if err != nil {
		return nil, nil, err
	}

	idxStatePath := r.GetPath("multilogs", IndexNamePrivates, "idx-state")
	idxStateFile, err := os.Create(idxStatePath) // OpenFile(|create) ?
	if err != nil {
		return nil, nil, err
	}
	snk := multilog.NewSink(idxStateFile, mlog, pr.update)

	return mlog, snk, nil
}

func (pr Private) update(ctx context.Context, seq int64, val interface{}, mlog multilog.MultiLog) error {
	if nulled, ok := val.(error); ok {
		if margaret.IsErrNulled(nulled) {
			return nil
		}
		return nulled
	}

	msg, ok := val.(refs.Message)
	if !ok {
		err := fmt.Errorf("private/readidx: error casting message. got type %T", val)
		return err
	}

	var boxedContent []byte
	switch msg.Author().Algo() {
	case refs.RefAlgoFeedSSB1:
		input := msg.ContentBytes()
		if !(input[0] == '"' && input[len(input)-1] == '"') {
			return nil // not a json string
		}
		b64data := bytes.TrimSuffix(input[1:], []byte(".box\""))
		boxedData := make([]byte, len(b64data))
		n, err := base64.StdEncoding.Decode(boxedData, b64data)
		if err != nil {
			err = fmt.Errorf("private/readidx: invalid b64 encoding: %w", err)
			level.Debug(pr.logger).Log("msg", "unboxLog b64 decode failed", "err", err)
			return nil
		}
		boxedContent = boxedData[:n]

	case refs.RefAlgoFeedGabby:
		mm, ok := val.(multimsg.MultiMessage)
		if !ok {
			mmPtr, ok := val.(*multimsg.MultiMessage)
			if !ok {
				err := fmt.Errorf("private/readidx: error casting message. got type %T", val)
				return err
			}
			mm = *mmPtr
		}
		tr, ok := mm.AsGabby()
		if !ok {
			err := errors.New("private/readidx: error getting gabby msg")
			return err
		}
		evt, err := tr.UnmarshaledEvent()
		if err != nil {
			return fmt.Errorf("private/readidx: error unpacking event from stored message: %w", err)
		}
		if evt.Content.Type != gabbygrove.ContentTypeArbitrary {
			return nil
		}
		boxedContent = bytes.TrimPrefix(tr.Content, []byte("box1:"))

	default:
		err := fmt.Errorf("private/readidx: unknown feed type: %s", msg.Author().Algo())
		level.Warn(pr.logger).Log("msg", "unahndled type", "err", err)
		return err
	}

	for _, kp := range pr.keyPairs {
		if _, err := pr.boxer.Decrypt(kp, boxedContent); err != nil {
			continue
		}
		userPrivs, err := mlog.Get(storedrefs.Feed(kp.ID()))
		if err != nil {
			return fmt.Errorf("private/readidx: error opening priv sublog for %s: %w", kp.ID().Ref(), err)
		}
		_, err = userPrivs.Append(seq)
		if err != nil {
			return fmt.Errorf("private/readidx: error appending PM for %s: %w", kp.ID().Ref(), err)
		}
	}
	return nil
}
