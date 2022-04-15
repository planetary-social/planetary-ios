package main

import (
	"bytes"
	"encoding/json"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
	"runtime/debug"
)

import "C"

//export ssbGenKey
func ssbGenKey() *C.char {
	defer logPanic()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("genKeyErr", err)
		}
	}()

	kp, err := ssb.NewKeyPair(nil, refs.RefAlgoFeedSSB1)
	if err != nil {
		err = errors.Wrap(err, "GenerateKeyPair: keygen failed")
		return nil
	}

	buf := &bytes.Buffer{}

	err = ssb.EncodeKeyPairAsJSON(kp, buf)
	if err != nil {
		err = errors.Wrap(err, "GenerateKeyPair: failed to encode key pair as JSON")
		return nil
	}

	return C.CString(string(buf.Bytes()))
}

//export ssbReplicateUpTo
func ssbReplicateUpTo() int {
	return -1
}

//export ssbOffsetFSCK
func ssbOffsetFSCK(mode uint32, progressFn uintptr) int {
	return 0
}

//export ssbHealRepo
func ssbHealRepo() *C.char {
	var err error
	defer logError("ssbHealRepo", &err)

	report := healReport{
		Authors:  make([]refs.FeedRef, 0),
		Messages: 0,
	}

	b, err := json.Marshal(report)
	if err != nil {
		err = errors.Wrap(err, "json marshal failed")
		return nil
	}

	return C.CString(string(b))
}

//export planetaryBearerToken
func planetaryBearerToken() *C.char {
	return nil
}

type healReport struct {
	Authors  []refs.FeedRef
	Messages uint64
}

func logError(functionName string, errPtr *error) {
	if err := *errPtr; err != nil {
		level.Error(log).Log("function", functionName, "error", err)
	}
}

func logPanic() {
	if p := recover(); p != nil {
		level.Error(log).Log("panic", p, "stack", string(debug.Stack()))
		panic(p)
	}
}
