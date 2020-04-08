package main

import (
	"bytes"
	"context"
	"encoding/json"
	"time"

	"github.com/go-kit/kit/log/level"

	"github.com/cryptix/go/encodedTime"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/private"
)

import "C"

//export ssbStreamRootLog
func ssbStreamRootLog(seq uint64, limit int) *C.char {
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

	buf, err := newLogDrain(sbot.RootLog, seq, limit)
	if err != nil {
		err = errors.Wrap(err, "rootLog: draining failed")
		return nil
	}

	return C.CString(buf.String())
}

//export ssbStreamPrivateLog
func ssbStreamPrivateLog(seq uint64, limit int) *C.char {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("ssbStreamPrivateLog", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		return nil
	}
	lock.Unlock()

	pl, ok := sbot.GetMultiLog("privLogs")
	if !ok {
		err = errors.Errorf("sbot: missing privLogs index")
		return nil
	}

	userPrivs, err := pl.Get(sbot.KeyPair.Id.StoredAddr())
	if err != nil {
		err = errors.Wrap(err, "failed to open user private index")
		return nil
	}

	unboxlog := private.NewUnboxerLog(sbot.RootLog, userPrivs, sbot.KeyPair)
	buf, err := newLogDrain(unboxlog, seq, limit)
	if err != nil {
		err = errors.Wrap(err, "PrivateLog: pipe draining failed")
		return nil
	}

	return C.CString(buf.String())
}

func newLogDrain(sourceLog margaret.Log, seq uint64, limit int) (*bytes.Buffer, error) {
	start := time.Now()

	w := &bytes.Buffer{}

	src, err := sourceLog.Query(
		margaret.SeqWrap(true),
		margaret.Gte(margaret.BaseSeq(seq)),
		margaret.Limit(limit*3)) // HACK: we know we will get less because we skip a lot of stuff but it's dangerous
	if err != nil {
		return nil, errors.Wrapf(err, "drainLog: failed to open query")
	}

	noNulled := mfr.FilterFunc(func(ctx context.Context, v interface{}) (bool, error) {
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
		msg, ok := wrappedVal.(ssb.Message)
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

	i := 0
	w.WriteString("[")
	for {
		v, err := src.Next(longCtx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			return nil, errors.Wrapf(err, "drainLog: failed to drain log msg:%d", i)
		}

		sw, ok := v.(margaret.SeqWrapper)
		if !ok {
			return nil, errors.Errorf("drainLog: want wrapper type got: %T", v)
		}

		rxLogSeq := sw.Seq().Seq()
		wrappedVal := sw.Value()
		msg, ok := wrappedVal.(ssb.Message)
		if !ok {
			return nil, errors.Errorf("drainLog: want msg type got: %T", wrappedVal)
		}

		if i > 0 {
			w.WriteString(",")
		}

		var kv struct {
			ssb.KeyValueRaw
			ReceiveLogSeq int64 // the sequence no of the log its stored in
		}
		kv.ReceiveLogSeq = rxLogSeq
		kv.Key_ = msg.Key()
		kv.Value = *msg.ValueContent()
		kv.Timestamp = encodedTime.Millisecs(msg.Received())
		if err := json.NewEncoder(w).Encode(kv); err != nil {
			return nil, errors.Wrapf(err, "drainLog: failed to k:v map message %d", i)
		}

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
