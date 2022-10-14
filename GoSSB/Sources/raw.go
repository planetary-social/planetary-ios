package main

import "C"
import (
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb/multilogs"
	refs "go.mindeco.de/ssb-refs"
)

// ssbGetRawMessage returns a raw message JSON for the specified feed and sequence number. Feed is in the @-notation,
// sequence starts at 1.
//export ssbGetRawMessage
func ssbGetRawMessage(feedRef string, seq int64) *C.char {
	defer logPanic()

	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("where", "ssbGetRawMessage", "err", retErr)
		}
	}()

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		retErr = ErrNotInitialized
		return nil
	}

	ref, err := refs.ParseFeedRef(feedRef)
	if err != nil {
		retErr = errors.Wrap(err, "error parsing feed ref")
		return nil
	}

	addr, err := feedStoredAddr(ref)
	if err != nil {
		retErr = errors.Wrap(err, "failed to get the address used for storage")
		return nil
	}

	uf, ok := sbot.GetMultiLog(multilogs.IndexNameFeeds)
	if !ok {
		retErr = errors.New("failed to get the multilog")
		return nil
	}

	log, err := uf.Get(addr)
	if err != nil {
		retErr = errors.Wrap(err, "could not get the log")
		return nil
	}

	sequenceNumberInReceiveLog, err := log.Get(seq - 1)
	if err != nil {
		retErr = errors.Wrap(err, "could not get the message")
		return nil
	}

	sequenceNumberInReceiveLogInt, ok := sequenceNumberInReceiveLog.(int64)
	if !ok {
		retErr = errors.New("sequence number type is invalid")
		return nil
	}

	msgInterface, err := sbot.ReceiveLog.Get(sequenceNumberInReceiveLogInt)
	if err != nil {
		retErr = errors.Wrap(err, "could not get message from receive log")
		return nil
	}

	msg, ok := msgInterface.(refs.Message)
	if !ok {
		retErr = errors.New("message has invalid type")
		return nil
	}

	return C.CString(string(msg.ValueContentJSON()))
}
