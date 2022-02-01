package main

import "C"
import (
	"crypto/rand"
	"encoding/json"
	"go.cryptoscope.co/ssb/private/box"
	refs "go.mindeco.de/ssb-refs"
	"strings"
	"sync"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
)

var publishLock sync.Mutex

//export ssbPublish
func ssbPublish(content string) *C.char {
	lock.Lock()
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "publish", "err", err)
		}
	}()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return nil
	}
	publishLock.Lock()
	defer publishLock.Unlock()
	lock.Unlock()

	n := len(content)
	if n > 8*1024 { // TODO: check feed format (gg can do 64k)
		err = errors.Errorf("publish: msg too big (got %d bytes)", n)
		return nil
	}

	newMsgRef, err := sbot.PublishLog.Publish(json.RawMessage(content))
	if err != nil {
		err = errors.Wrap(err, "publish: failed to append value")
		return nil
	}

	return C.CString(newMsgRef.Ref())
}

//export ssbPublishPrivate
func ssbPublishPrivate(content, recps string) *C.char {
	lock.Lock()
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "publish private", "err", err)
		}
	}()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return nil
	}
	publishLock.Lock()
	defer publishLock.Unlock()
	lock.Unlock()

	var rcpsRefs []refs.FeedRef
	for i, rstr := range strings.Split(recps, ";") {
		ref, err := refs.ParseFeedRef(rstr)
		if err != nil {
			err = errors.Wrapf(err, "private/publish: failed to parse recipient %d", i)
			return nil
		}
		rcpsRefs = append(rcpsRefs, ref)
	}

	boxer := box.NewBoxer(rand.Reader)

	boxedMsg, err := boxer.Encrypt(json.RawMessage(content), rcpsRefs...)
	if err != nil {
		err = errors.Wrap(err, "private/publish: failed to box message")
		return nil
	}

	newMsgRef, err := sbot.PublishLog.Publish(boxedMsg)
	if err != nil {
		err = errors.Wrap(err, "private/publish: failed to append value")
		return nil
	}

	n := len(boxedMsg)
	if n > 8*1024 { // TODO: check feed format (gg can do 64k)
		err = errors.Errorf("private/publish: msg too big (got %d bytes)", n)
		return nil
	}

	return C.CString(newMsgRef.Ref())
}
