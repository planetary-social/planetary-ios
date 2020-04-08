package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"time"
	"unsafe"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/ssb"
	mksbot "go.cryptoscope.co/ssb/sbot"
)

// #include <stdlib.h>
// #include <sys/types.h>
// #include <stdint.h>
// #include <stdbool.h>
// static void callFSCKProgressNotify(void *func, double percentage, const char* remaining)
// {
//   ((void(*)(double, const char*))func)(percentage, remaining);
// }
import "C"

//export ssbGenKey
func ssbGenKey() *C.char {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("genKeyErr", err)
		}
	}()

	kp, err := ssb.NewKeyPair(nil)
	if err != nil {
		err = errors.Wrap(err, "GenerateKeyPair: keygen failed")
		return nil
	}

	var sec = jsonSecret{
		Curve:   "ed25519",
		ID:      kp.Id,
		Private: base64.StdEncoding.EncodeToString(kp.Pair.Secret[:]) + ".ed25519",
		Public:  base64.StdEncoding.EncodeToString(kp.Pair.Public[:]) + ".ed25519",
	}

	bytes, err := json.Marshal(sec)
	if err != nil {
		err = errors.Wrap(err, "GenerateKeyPair: json encoding failed")
		return nil
	}
	return C.CString(string(bytes))
}

// todo: deduplicate
type jsonSecret struct {
	Curve   string       `json:"curve"`
	ID      *ssb.FeedRef `json:"id"`
	Private string       `json:"private"`
	Public  string       `json:"public"`
}

//export ssbReplicateUpTo
func ssbReplicateUpTo() int {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("ssbReplicateUpTo", err)
		}
	}()

	uf, ok := sbot.GetMultiLog("userFeeds")
	if !ok {
		err = errors.Errorf("sbot: missing userFeeds index")
		return -1
	}

	knownFeeds, err := uf.List()
	if err != nil {
		err = errors.Wrap(err, "feeds: failed to feed listing")
		return -1
	}

	feedCnt := make(map[string]int64, len(knownFeeds))
	for i, addr := range knownFeeds {
		subLog, err := uf.Get(addr)
		if err != nil {
			err = errors.Wrapf(err, "feeds: log(%d) failed to open", i)
			return -1
		}

		ms, err := subLog.Seq().Value()
		if err != nil {
			err = errors.Wrapf(err, "feeds: log(%d) failed to get current seq", i)
			return -1
		}
		var fr ssb.FeedRef
		fr.Algo = "ed25519"
		fr.ID = []byte(addr)
		feedCnt[fr.Ref()] = ms.(margaret.Seq).Seq()
	}

	r, w, err := os.Pipe()
	if err != nil {
		err = errors.Wrap(err, "os.Pipe creation failed")
		return -1
	}

	go func() {
		err = json.NewEncoder(w).Encode(feedCnt)
		if err != nil {
			log.Log("ssbReplicateUpTo", err)
		}
		err = w.Close()
		log.Log("ssbReplicateUpTo", "done", "closeErr", err)
	}()

	fdptr := r.Fd()
	fd, err := strconv.Atoi(fmt.Sprint(fdptr))
	if err != nil {
		err = errors.Wrap(err, "ssbReplicateUpTo: failed to transfer FD")
		return -1
	}

	return fd
}

var lastFSCK mksbot.ErrConsistencyProblems

//export ssbOffsetFSCK
func ssbOffsetFSCK(mode uint32, progressFn uintptr) int {
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("ssbOffsetFSCK", retErr, "mode", mode)
		}
	}()

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		retErr = ErrNotInitialized
		return -1
	}

	fsckMode := mksbot.FSCKMode(mode)
	if fsckMode != mksbot.FSCKModeLength && fsckMode != mksbot.FSCKModeSequences {
		retErr = errors.Errorf("fsck: invalid mode %d", fsckMode)
		return -1
	}

	progressFuncPtr := unsafe.Pointer(progressFn)
	wrapFn := func(perc float64, remaining time.Duration) {
		remainingCstr := C.CString(remaining.String())
		C.callFSCKProgressNotify(progressFuncPtr, C.double(perc), remainingCstr)
		C.free(unsafe.Pointer(remainingCstr))
	}

	retErr = sbot.FSCK(mksbot.FSCKWithMode(fsckMode), mksbot.FSCKWithProgress(wrapFn))
	if retErr != nil {
		if constErrs, ok := retErr.(mksbot.ErrConsistencyProblems); ok {
			lastFSCK = constErrs
		}
		return -1
	}

	return 0
}

//export ssbHealRepo
func ssbHealRepo() *C.char {
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("ssbHealRepo", retErr)
		}
	}()

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		retErr = ErrNotInitialized
		return nil
	}

	sbot.Network.GetConnTracker().CloseAll()

	retErr = sbot.HealRepo(lastFSCK)
	if retErr != nil {
		return nil
	}

	var rep healReport
	for _, errs := range lastFSCK.Errors {
		rep.Authors = append(rep.Authors, errs.Ref)
	}
	rep.Messages = lastFSCK.Sequences.GetCardinality()

	lastFSCK.Sequences = nil
	lastFSCK.Errors = nil

	bytes, err := json.Marshal(rep)
	if err != nil {
		retErr = errors.Wrap(err, "ssbHealRepo: json encoding report failed")
		return nil
	}
	return C.CString(string(bytes))
}

type healReport struct {
	Authors  []*ssb.FeedRef
	Messages uint64
}
