//go:build testing
// +build testing

package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"go.cryptoscope.co/ssb/private/box"
	"strings"

	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb/repo"
	refs "go.mindeco.de/ssb-refs"
)

import "C"

//export ssbTestingMakeNamedKey
func ssbTestingMakeNamedKey(name string) int {
	testRepo := repo.New(repoDir)
	h := sha256.New()
	fmt.Fprint(h, name)
	_, err := repo.NewKeyPairFromSeed(testRepo, name, refs.RefAlgoFeedSSB1, bytes.NewReader(h.Sum(nil)))
	if err != nil {
		return -1
	}
	return 0
}

//export ssbTestingAllNamedKeypairs
func ssbTestingAllNamedKeypairs() *C.char {
	var err error
	defer func() {
		if err != nil {
			log.Log("where", "ssbTestingPublishAs", "err", err)
		}
	}()
	testRepo := repo.New(repoDir)

	pairs, err := repo.AllKeyPairs(testRepo)
	if err != nil {
		err = errors.Wrap(err, "failed to get all keypairs")
		return nil
	}

	pubkeys := make(map[string]string, len(pairs))
	for name, kp := range pairs {
		pubkeys[name] = kp.ID().Sigil()
	}

	jsonMap, err := json.Marshal(pubkeys)
	if err != nil {
		err = errors.Wrap(err, "failed to marshal pubkey map")
		return nil
	}

	return C.CString(string(jsonMap))
}

//export ssbTestingPublishAs
func ssbTestingPublishAs(nick, content string) *C.char {
	lock.Lock()
	defer lock.Unlock()
	var err error
	defer func() {
		if err != nil {
			log.Log("where", "ssbTestingPublishAs", "err", err)
		}
	}()
	if sbot == nil {
		err = ErrNotInitialized
		return nil
	}

	newRef, err := sbot.PublishAs(nick, json.RawMessage(content))
	if err != nil {
		err = errors.Wrapf(err, "ssbTestingPublishAs: failed to publush value as %s", nick)
		return nil
	}
	return C.CString(newRef.Key().Sigil())
}

//export ssbTestingPublishPrivateAs
func ssbTestingPublishPrivateAs(nick, content, recps string) *C.char {
	lock.Lock()
	var err error
	defer func() {
		if err != nil {
			log.Log("where", "publishPrivateAs", "err", err)
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
			err = errors.Wrapf(err, "private/publishAs: failed to parse recipient %d", i)
			return nil
		}
		rcpsRefs = append(rcpsRefs, ref)
	}

	boxedMsg, err := box.NewBoxer(nil).Encrypt(json.RawMessage(content), rcpsRefs...)
	if err != nil {
		err = errors.Wrap(err, "private/publishAs: failed to box message")
		return nil
	}

	newMsgRef, err := sbot.PublishAs(nick, boxedMsg)
	if err != nil {
		err = errors.Wrap(err, "private/publishAs: failed to append value")
		return nil
	}

	n := len(boxedMsg)
	if n > 8*1024 { // TODO: check feed format (gg can do 64k)
		err = errors.Errorf("private/publishAs: msg too big (got %d bytes)", n)
		return nil
	}

	return C.CString(newMsgRef.Key().Sigil())
}
