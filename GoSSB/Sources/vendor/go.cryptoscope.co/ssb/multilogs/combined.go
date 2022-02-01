package multilogs

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"

	"github.com/dgraph-io/sroar"
	"github.com/keks/persist"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/margaret/multilog/roaring"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/statematrix"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message/multimsg"
	"go.cryptoscope.co/ssb/private"
	"go.cryptoscope.co/ssb/repo"
	gabbygrove "go.mindeco.de/ssb-gabbygrove"
	refs "go.mindeco.de/ssb-refs"
)

// NewCombinedIndex creates one big index which updates the multilogs users, byType, private and tangles.
// Compared to the "old" fatbot approach of just having 4 independant indexes,
// this one updates all 4 of them, resulting in less read-overhead
// while also being able to index private massages by tangle and type.
func NewCombinedIndex(
	repoPath string,
	box *private.Manager,
	self refs.FeedRef,
	rxlog margaret.Log,
	u, p, bt, tan *roaring.MultiLog,
	oh multilog.MultiLog,
	sm *statematrix.StateMatrix,
) (*CombinedIndex, error) {
	r := repo.New(repoPath)
	statePath := r.GetPath(repo.PrefixMultiLog, "combined-state.json")
	mode := os.O_RDWR | os.O_EXCL
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		mode |= os.O_CREATE
	}
	os.MkdirAll(filepath.Dir(statePath), 0700)
	idxStateFile, err := os.OpenFile(statePath, mode, 0700)
	if err != nil {
		return nil, fmt.Errorf("error opening state file: %w", err)
	}

	idx := &CombinedIndex{
		self:  self,
		boxer: box,

		// application multilogs
		users:   u,
		private: p,
		byType:  bt,
		tangles: tan,

		ebtState: sm,

		// groups reindexing
		rxlog:        rxlog,
		orderdHelper: oh,

		file: idxStateFile,
		l:    &sync.Mutex{},
	}
	return idx, nil
}

var _ indexes.SinkIndex = (*CombinedIndex)(nil)

type CombinedIndex struct {
	self  refs.FeedRef
	boxer *private.Manager

	rxlog margaret.Log

	users   *roaring.MultiLog
	private *roaring.MultiLog
	byType  *roaring.MultiLog
	tangles *roaring.MultiLog

	orderdHelper multilog.MultiLog

	ebtState *statematrix.StateMatrix

	file *os.File
	l    *sync.Mutex
}

// Box2Reindex takes advantage of the other bitmap indexes to reindex just the messages from the passed author that are box2 but not yet readable by us.
//	1) taking private:meta:box2
//	2) ANDing it with the one of the author (intersection)
//	3) subtracting all the messages we _can_ read (private:box2:$ourFeed)
func (idx *CombinedIndex) Box2Reindex(author refs.FeedRef) error {
	idx.l.Lock()
	defer idx.l.Unlock()

	// 1) all messages in boxed2 format
	allBox2, err := idx.private.LoadInternalBitmap(indexes.Addr("meta:box2"))
	if err != nil {
		return fmt.Errorf("error getting all box2 messages: %w", err)
	}

	// 2) all messages by the author we should re-index
	fromAuthor, err := idx.users.LoadInternalBitmap(storedrefs.Feed(author))
	if err != nil {
		if !errors.Is(err, multilog.ErrSublogNotFound) {
			return fmt.Errorf("error getting all from author: %w", err)
		}
		fromAuthor = sroar.NewBitmap()
	}

	// 2) intersection between the two
	fromAuthor.And(allBox2)

	if fromAuthor.GetCardinality() == 0 {
		fmt.Println("skipping empty set", allBox2.GetCardinality(), author.Ref())
		return nil
	}

	// 3) all messages we can already decrypt
	myReadableAddr := indexes.Addr("box2:") + storedrefs.Feed(idx.self)
	myReadable, err := idx.private.LoadInternalBitmap(myReadableAddr)
	if err != nil {
		return fmt.Errorf("error getting my readable: %w", err)
	}

	// 3) subtract those from 2)
	fromAuthor.AndNot(myReadable)

	it := fromAuthor.NewIterator()

	// iterate over those and reindex them
	for it.HasNext() {
		rxSeq := int64(it.Next())

		msgv, err := idx.rxlog.Get(rxSeq)
		if err != nil {
			return err
		}

		msg, ok := msgv.(refs.Message)
		if !ok {
			return fmt.Errorf("not a message: %T", msgv)
		}

		err = idx.update(rxSeq, msg)
		if err != nil {
			return err
		}
	}

	return nil
}

// Pour calls the processing function to add a value to a sublog.
func (idx *CombinedIndex) Pour(ctx context.Context, swv interface{}) error {
	idx.l.Lock()
	defer idx.l.Unlock()

	sw, ok := swv.(margaret.SeqWrapper)
	if !ok {
		return fmt.Errorf("error casting seq wrapper. got type %T", swv)
	}
	seq := int64(sw.Seq()) //received as

	// todo: defer state save!?
	err := persist.Save(idx.file, seq)
	if err != nil {
		return fmt.Errorf("error saving current sequence number: %w", err)
	}

	v := sw.Value()

	if isNulled, ok := v.(error); ok {
		if margaret.IsErrNulled(isNulled) {
			return nil
		}
		return isNulled
	}

	msg, ok := v.(refs.Message)
	if !ok {
		return fmt.Errorf("error casting message. got type %T", v)
	}

	return idx.update(seq, msg)
}

// update all the indexes with this new message which was stored as rxSeq (received sequence number)
func (idx *CombinedIndex) update(rxSeq int64, msg refs.Message) error {

	author := msg.Author()

	authorAddr := storedrefs.Feed(author)
	authorLog, err := idx.users.Get(authorAddr)
	if err != nil {
		return fmt.Errorf("error opening sublog: %w", err)
	}
	_, err = authorLog.Append(rxSeq)
	if err != nil {
		return fmt.Errorf("error updating author sublog: %w", err)
	}

	// TODO: batch/debounce me
	err = idx.ebtState.Fill(idx.self, []statematrix.ObservedFeed{{
		Feed: author,
		Note: ssb.Note{
			Seq:       int64(msg.Seq()),
			Receive:   true,
			Replicate: true,
		},
	}})
	if err != nil {
		return fmt.Errorf("ebt update failed: %w", err)
	}

	// decrypt box 1 & 2
	content := msg.ContentBytes()
	// TODO: gabby grove
	if content[0] != '{' { // assuming all other content is json objects
		cleartext, err := idx.tryDecrypt(msg, rxSeq)
		if err != nil {
			if err == errSkip {
				// yes it's a boxed message but we can't read it (yet)
				return nil
			}
			// something went horribly wrong
			return err
		}
		content = cleartext
	}

	// by type:...  and tangles (v1 & v2)
	var jsonContent struct {
		Type    string
		Root    *refs.MessageRef
		Tangles refs.Tangles
		// Mentions [] TODO channels and mentions
	}
	err = json.Unmarshal(content, &jsonContent)
	if err != nil {
		// fmt.Errorf("ssb: combined idx failed to unmarshal json content of %s: %w", abstractMsg.Key().Ref(), err)
		// returning an error in this pipeline stops the processing,
		// i.e. broken messages stop all other indexing
		// not much to do here but continue with the next
		// these can be quite educational though (like root: bool)
		//
		// TODO: make a "forgiving" content type
		// which silently ignores invalid root: or tangle fields.
		// right now these don't end up in byType or tangles
		return nil
	}

	typeStr := jsonContent.Type
	if typeStr == "" {
		// TODO: dont stop indexing on illegal messages
		return nil
		// return fmt.Errorf("ssb: untyped message")
	}
	typeIdxAddr := indexes.Addr("string:" + typeStr)

	// we need to keep the order intact for these
	if typeStr == "group/add-member" {
		sl, err := idx.orderdHelper.Get(typeIdxAddr)
		if err != nil {
			return err
		}
		_, err = sl.Append(rxSeq)
		if err != nil {
			return err
		}
	}

	typedLog, err := idx.byType.Get(typeIdxAddr)
	if err != nil {
		return fmt.Errorf("error opening sublog: %w", err)
	}

	_, err = typedLog.Append(rxSeq)
	if err != nil {
		return fmt.Errorf("error updating byType sublog: %w", err)
	}

	// tangles v1 and v2
	if jsonContent.Root != nil {
		addr := storedrefs.TangleV1(*jsonContent.Root)
		tangleLog, err := idx.tangles.Get(addr)
		if err != nil {
			return fmt.Errorf("error opening sublog: %w", err)
		}
		_, err = tangleLog.Append(rxSeq)
		if err != nil {
			return fmt.Errorf("error updating v1 tangle sublog: %w", err)
		}
	}

	for tname, tip := range jsonContent.Tangles {
		if tname == "" {
			continue
		}
		if tip.Root == nil {
			continue
		}
		addr := storedrefs.TangleV2(tname, *tip.Root)
		tangleLog, err := idx.tangles.Get(addr)
		if err != nil {
			return fmt.Errorf("error opening sublog: %w", err)
		}
		_, err = tangleLog.Append(rxSeq)
		if err != nil {
			return fmt.Errorf("error updating v2 tangle sublog: %w", err)
		}
	}

	return nil
}

func (idx *CombinedIndex) Close() error {
	return idx.file.Close()
}

// QuerySpec returns the query spec that queries the next needed messages from the log
func (idx *CombinedIndex) QuerySpec() margaret.QuerySpec {
	idx.l.Lock()
	defer idx.l.Unlock()

	var seq int64

	if err := persist.Load(idx.file, &seq); err != nil {
		if !errors.Is(err, io.EOF) {
			return margaret.ErrorQuerySpec(err)
		}

		seq = margaret.SeqEmpty
	}

	return margaret.MergeQuerySpec(
		margaret.Gt(seq),
		margaret.SeqWrap(true),
	)
}

func (idx *CombinedIndex) tryDecrypt(msg refs.Message, rxSeq int64) ([]byte, error) {
	box1, box2, err := getBoxedContent(msg)
	if err != nil {
		// not super sure what the idea with the different skip errors was
		// these are _broken_ content-wise both kinds _should be ignored
		if err == errSkipBox1 || err == errSkipBox2 {
			return nil, errSkip
		}

		return nil, err
	}

	var (
		cleartext []byte
		idxAddr   indexes.Addr
	)

	// as a help for re-indexing, keep track of all box1 and box2 messages.
	if box1 != nil {
		idxAddr = indexes.Addr("meta:box1")
	} else {
		idxAddr = indexes.Addr("meta:box2")
	}

	boxTyped, err := idx.private.Get(idxAddr)
	if err != nil {
		return nil, err
	}
	if _, err := boxTyped.Append(rxSeq); err != nil {
		return nil, fmt.Errorf("private: error marking type:box: %w", err)
	}

	// try decrypt and pass on the clear text
	if box1 != nil {
		content, err := idx.boxer.DecryptBox1(box1)
		if err != nil {
			return nil, errSkip
		}

		idxAddr = indexes.Addr("box1:") + storedrefs.Feed(idx.self)
		cleartext = content
	} else if box2 != nil {
		prev := refs.MessageRef{}
		if p := msg.Previous(); p != nil {
			prev = *p
		}
		content, err := idx.boxer.DecryptBox2(box2, msg.Author(), prev)
		if err != nil {
			return nil, errSkip
		}

		// instead by group root? could be PM... hmm
		// would be nice to keep multi-keypair support here
		// but might need to rethink the group manager
		idxAddr = indexes.Addr("box2:") + storedrefs.Feed(idx.self)
		cleartext = content
	} else {
		return nil, fmt.Errorf("tryDecrypt: not skipped but also not valid content")
	}

	userPrivs, err := idx.private.Get(idxAddr)
	if err != nil {
		return nil, fmt.Errorf("combined/private: error opening priv sublog for: %w", err)
	}
	if _, err := userPrivs.Append(rxSeq); err != nil {
		return nil, fmt.Errorf("combined/private: error appending PM: %w", err)
	}

	return cleartext, nil
}

var (
	errSkip     = fmt.Errorf("ssb: skip - not for us")
	errSkipBox1 = fmt.Errorf("ssb: skip box1 message")
	errSkipBox2 = fmt.Errorf("ssb: skip box2 message")
)

// returns either box1, box2 content or an error
// if err == errSkip, this message couldn't be decrypted
// everything else is a broken message (TODO: and should be... ignored?)
func getBoxedContent(msg refs.Message) ([]byte, []byte, error) {
	switch msg.Author().Algo() {

	// on the _crappy_ format, we need to base64 decode the data
	case refs.RefAlgoFeedSSB1:
		input := msg.ContentBytes()
		if !(input[0] == '"' && input[len(input)-1] == '"') {
			return nil, nil, errSkipBox1 // not a json string
		}

		if bytes.HasSuffix(input[1:], []byte(".box\"")) {
			b64data := bytes.TrimSuffix(input[1:], []byte(".box\""))
			boxedData := make([]byte, base64.StdEncoding.DecodedLen(len(input)-6))
			n, err := base64.StdEncoding.Decode(boxedData, b64data)
			if err != nil {
				//err = errors.Wrap(err, "combined/private: invalid b64 encoding")
				//level.Debug(pr.logger).Log("msg", "unboxLog b64 decode failed", "err", err)
				return nil, nil, errSkipBox1
			}
			return boxedData[:n], nil, nil
		} else if bytes.HasSuffix(input[1:], []byte(".box2\"")) {
			b64data := bytes.TrimSuffix(input[1:], []byte(".box2\""))
			boxedData := make([]byte, base64.StdEncoding.DecodedLen(len(input)-7))
			n, err := base64.StdEncoding.Decode(boxedData, b64data)
			if err != nil {
				err = fmt.Errorf("combined/private: invalid b64 encoding: %w", err)
				//level.Debug(pr.logger).Log("msg", "unboxLog b64 decode failed", "err", err)
				return nil, nil, errSkipBox1
			}
			return nil, boxedData[:n], nil
		} else {
			return nil, nil, fmt.Errorf("private/ssb1: unknown content type: %q", input[len(input)-10:])
		}

		// gg supports pure binary data
	case refs.RefAlgoFeedGabby:
		// TODO: use ContentBytes()?
		mm, ok := msg.(multimsg.MultiMessage)
		if !ok {
			mmPtr, ok := msg.(*multimsg.MultiMessage)
			if !ok {
				err := fmt.Errorf("combined/private: error casting message. got type %T", msg)
				return nil, nil, err
			}
			mm = *mmPtr
		}
		tr, ok := mm.AsGabby()
		if !ok {
			return nil, nil, fmt.Errorf("combined/private: error getting gabby msg")
		}

		evt, err := tr.UnmarshaledEvent()
		if err != nil {
			return nil, nil, fmt.Errorf("combined/private: error unpacking event from stored message: %w", err)
		}
		if evt.Content.Type != gabbygrove.ContentTypeArbitrary {
			return nil, nil, errSkipBox2
		}

		var (
			prefixBox1 = []byte("box1:")
			prefixBox2 = []byte("box2:")
		)
		switch {
		case bytes.HasPrefix(tr.Content, prefixBox1):
			return tr.Content[5:], nil, nil
		case bytes.HasPrefix(tr.Content, prefixBox2):
			return nil, tr.Content[5:], nil
		default:
			return nil, nil, fmt.Errorf("private/ssb1: unknown content type: %s", msg.Key().ShortRef())
		}

	case refs.RefAlgoFeedBendyButt:
		// TODO: check first bytes and strip prefix
		return nil, nil, errSkipBox2

	default:
		err := fmt.Errorf("combined/private: unknown feed type: %s", msg.Author().Algo())
		return nil, nil, err
	}

}
