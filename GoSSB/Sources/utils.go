package main

import (
	"bytes"
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
