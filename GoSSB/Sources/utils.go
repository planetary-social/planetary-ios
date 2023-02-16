package main

import (
	"bytes"
	"encoding/json"
	"runtime/debug"

	"github.com/pkg/errors"
	"github.com/ssbc/go-ssb"
	refs "github.com/ssbc/go-ssb-refs"
)

import "C"

//export ssbGenKey
func ssbGenKey() *C.char {
	defer logPanic()

	var err error
	defer logError("ssbGenKey", &err)

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

	return C.CString(buf.String())
}

//export ssbOffsetFSCK
func ssbOffsetFSCK(mode uint32, progressFn uintptr) int {
	defer logPanic()

	return 0
}

//export ssbHealRepo
func ssbHealRepo() *C.char {
	defer logPanic()

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

type healReport struct {
	Authors  []refs.FeedRef
	Messages uint64
}

func logError(functionName string, errPtr *error) {
	if err := *errPtr; err != nil {
		log.
			WithError(err).
			WithField("function", functionName).
			Error("function returned an error")
	}
}

func logPanic() {
	if p := recover(); p != nil {
		log.
			WithField("panic", p).
			WithField("stack", string(debug.Stack())).
			Error("encountered a panic")
		panic(p)
	}
}
