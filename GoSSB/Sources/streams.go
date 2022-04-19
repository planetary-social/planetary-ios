package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/ssb/multilogs"
	"go.mindeco.de/encodedTime"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
	"time"
)

import "C"

//export ssbStreamRootLog
func ssbStreamRootLog(seq int64, limit int) *C.char {
	defer logPanic()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("ssbStreamRootLog", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return nil
	}
	lock.Unlock()

	buf, err := newLogDrain(sbot.ReceiveLog, seq, limit)
	if err != nil {
		err = errors.Wrap(err, "rootLog: draining failed")
		return nil
	}

	return C.CString(buf.String())
}

//export ssbStreamPrivateLog
func ssbStreamPrivateLog(seq uint64, limit int) *C.char {
	// return empty array until there is actual UI in place for these
	return C.CString("[]")
	//var err error
	//defer func() {
	//	if err != nil {
	//		level.Error(log).Log("ssbStreamPrivateLog", err)
	//	}
	//}()
	//
	//lock.Lock()
	//if sbot == nil {
	//	err = ErrNotInitialized
	//	return nil
	//}
	//lock.Unlock()
	//
	//pl, ok := sbot.GetMultiLog("privLogs")
	//if !ok {
	//	err = errors.Errorf("sbot: missing privLogs index")
	//	return nil
	//}
	//
	//userPrivs, err := pl.Get(sbot.KeyPair.ID().StoredAddr())
	//if err != nil {
	//	err = errors.Wrap(err, "failed to open user private index")
	//	return nil
	//}
	//
	//unboxlog := private.NewUnboxerLog(sbot.ReceiveLog, userPrivs, sbot.KeyPair)
	//buf, err := newLogDrain(unboxlog, seq, limit)
	//if err != nil {
	//	err = errors.Wrap(err, "PrivateLog: pipe draining failed")
	//	return nil
	//}
	//
	//return C.CString(buf.String())
}

//export ssbStreamPublishedLog
// This function should fetch all the currently logged in user's posts aka the "publishedLog"
// The seq parameter should be the index of the last known message that the user published in the RootLog.
// Pass -1 to get the entire log.
func ssbStreamPublishedLog(afterSeq int64) *C.char {
	defer logPanic()

	// Please don't judge me too hard I don't know much Go - ml
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("ssbStreamPublishLog", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return nil
	}
	lock.Unlock()

	uf, ok := sbot.GetMultiLog(multilogs.IndexNameFeeds)
	if !ok {
		err = errors.Wrapf(err, "failed to get user feed")
		return nil
	}

	addr, err := feedStoredAddr(sbot.KeyPair.ID())
	if err != nil {
		err = errors.Wrap(err, "failed to get the address used for storage")
		return nil
	}

	publishedLog, err := uf.Get(addr)
	if err != nil {
		err = errors.Wrap(err, "userFeeds: could not get log for current user")
		return nil
	}

	start := time.Now()

	w := &bytes.Buffer{}

	// This creates a stream of indexes of messages the user has published.
	src, err := publishedLog.Query(
		margaret.SeqWrap(true))

	if err != nil {
		errors.Wrapf(err, "drainLog: failed to open query")
		return nil
	}

	keyHasher := sha256.New()
	i := 0
	w.WriteString("[")
	for {
		v, err := src.Next(longCtx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			if margaret.IsErrNulled(errors.Cause(err)) {
				continue
			}
			errors.Wrapf(err, "drainLog: failed to drain log msg:%d", i)
			return nil
		}

		sw, ok := v.(margaret.SeqWrapper)
		if !ok {
			errors.Errorf("drainLog: want wrapper type got: %T", v)
			return nil
		}

		wrappedVal := sw.Value()
		indexOfMessageInRootLog, ok := wrappedVal.(int64)
		if !ok {
			errors.Errorf("drainLog: want msg type got: %T", wrappedVal)
			return nil
		}

		// Filter out messages before seq
		// This is an inefficient way to do this. Really we should be adding a filter to the publishLog.Query, but I'm not sure how to convert an index
		// in the RootLog to an index in the publishedLog
		if indexOfMessageInRootLog <= afterSeq {
			continue
		}

		v, err = sbot.ReceiveLog.Get(indexOfMessageInRootLog)
		if err != nil {
			errors.Wrapf(err, "drainLog: could not get message %d from RootLog", indexOfMessageInRootLog)
			return nil
		}

		msg, ok := v.(refs.Message)
		if !ok {
			errors.Errorf("drainLog: want msg type got: %T", wrappedVal)
			return nil
		}

		if i > 0 {
			w.WriteString(",")
		}

		var kv struct {
			refs.KeyValueRaw
			ReceiveLogSeq int64 // the sequence no of the log its stored in
			HashedKey     string
		}
		kv.ReceiveLogSeq = indexOfMessageInRootLog
		kv.Key_ = msg.Key()
		kv.Value = *msg.ValueContent()
		kv.Timestamp = encodedTime.Millisecs(msg.Received())

		keyHasher.Write([]byte(kv.Key_.String()))
		kv.HashedKey = fmt.Sprintf("%x", keyHasher.Sum(nil))

		if err := json.NewEncoder(w).Encode(kv); err != nil {
			errors.Wrapf(err, "drainLog: failed to k:v map message %d", i)
			return nil
		}
		keyHasher.Reset()

		i++
	}

	w.WriteString("]")

	if i > 0 {
		durr := time.Since(start)
		level.Info(log).Log("event", "fresh publishLog chunk", "msgs", i, "took", durr)
	}

	return C.CString(w.String())
}

func newLogDrain(sourceLog margaret.Log, seq int64, limit int) (*bytes.Buffer, error) {
	start := time.Now()

	w := &bytes.Buffer{}

	src, err := sourceLog.Query(
		margaret.SeqWrap(true),
		margaret.Gte(seq),
		margaret.Limit(limit*3)) // HACK: we know we will get less because we skip a lot of stuff but it's dangerous
	if err != nil {
		return nil, errors.Wrapf(err, "drainLog: failed to open query")
	}

	noNulled := mfr.FilterFunc(func(ctx context.Context, v interface{}) (bool, error) {
		sw, ok := v.(margaret.SeqWrapper)
		if ok {
			if err, ok := sw.Value().(error); ok && margaret.IsErrNulled(err) {
				return false, nil
			}
		}
		if err, ok := v.(error); ok {
			if margaret.IsErrNulled(err) {
				return false, nil
			}
			return false, err
		}
		return true, nil
	})
	src = mfr.SourceFilter(src, noNulled)

	sixMonthAgo := time.Now().Add(-6 * time.Hour * 24 * 30)

	nowOldStuff := func(ctx context.Context, v interface{}) (bool, error) {
		sw, ok := v.(margaret.SeqWrapper)
		if !ok {
			if errv, ok := v.(error); ok && margaret.IsErrNulled(errv) {
				return false, nil
			}
			return false, errors.Errorf("drainLog: want wrapper type got: %T", v)
		}
		wrappedVal := sw.Value()
		msg, ok := wrappedVal.(refs.Message)
		if !ok {
			return false, errors.Errorf("drainLog: want msg type got: %T", wrappedVal)
		}

		if msg.Claimed().Before(sixMonthAgo) {
			var typeMsg struct {
				Type string
			}

			err := json.Unmarshal(msg.ContentBytes(), &typeMsg)
			typeStr := typeMsg.Type
			if err != nil {
				return false, nil
			}
			// the app viewdb needs older about and contact info
			if typeStr == "about" || typeStr == "contact" {
				return true, nil
			}
			return false, nil
		}
		return true, nil
	}

	src = mfr.SourceFilter(src, nowOldStuff)

	keyHasher := sha256.New()
	i := 0
	w.WriteString("[")
	for {
		v, err := src.Next(longCtx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			if margaret.IsErrNulled(errors.Cause(err)) {
				continue
			}
			return nil, errors.Wrapf(err, "drainLog: failed to drain log msg:%d", i)
		}

		sw, ok := v.(margaret.SeqWrapper)
		if !ok {
			return nil, errors.Errorf("drainLog: want wrapper type got: %T", v)
		}

		rxLogSeq := sw.Seq()
		wrappedVal := sw.Value()
		msg, ok := wrappedVal.(refs.Message)
		if !ok {
			return nil, errors.Errorf("drainLog: want msg type got: %T", wrappedVal)
		}

		if i > 0 {
			w.WriteString(",")
		}

		var kv struct {
			refs.KeyValueRaw
			ReceiveLogSeq int64 // the sequence no of the log its stored in
			HashedKey     string
		}
		kv.ReceiveLogSeq = rxLogSeq
		kv.Key_ = msg.Key()
		kv.Value = *msg.ValueContent()
		kv.Timestamp = encodedTime.Millisecs(msg.Received())

		keyHasher.Write([]byte(kv.Key_.String()))
		kv.HashedKey = fmt.Sprintf("%x", keyHasher.Sum(nil))

		if err := json.NewEncoder(w).Encode(kv); err != nil {
			return nil, errors.Wrapf(err, "drainLog: failed to k:v map message %d", i)
		}
		keyHasher.Reset()

		if i > limit {
			break
		}
		i++
	}

	w.WriteString("]")

	if i > 0 {
		durr := time.Since(start)
		level.Info(log).Log("event", "fresh viewdb chunk", "msgs", i, "took", durr)
	}
	return w, nil

}

func feedStoredAddr(r refs.FeedRef) (indexes.Addr, error) {
	sr, err := tfk.FeedFromRef(r)
	if err != nil {
		return "", fmt.Errorf("failed to make stored feed ref: %w", err)
	}

	b, err := sr.MarshalBinary()
	if err != nil {
		return "", fmt.Errorf("error while marshalling stored feed ref: %w", err)
	}

	return indexes.Addr(b), nil
}
