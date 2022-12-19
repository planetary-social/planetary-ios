//go:build testing
// +build testing

package main

import "C"

import (
	"encoding/json"
	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
	"verseproj/scuttlegobridge/tests"
)

var testKeys = tests.NewTestKeys()

//export ssbTestingMakeNamedKey
func ssbTestingMakeNamedKey(name string) int {
	defer logPanic()

	var err error
	defer logError("ssbTestingMakeNamedKey", &err)

	err = testKeys.CreateNamedKey(name)
	if err != nil {
		err = errors.Wrap(err, "error creating named key")
		return -1
	}

	return 0
}

//export ssbTestingAllNamedKeypairs
func ssbTestingAllNamedKeypairs() *C.char {
	defer logPanic()

	var err error
	defer logError("ssbTestingAllNamedKeypairs", &err)

	result := make(map[string]string)

	for name, ref := range testKeys.ListNamedKeys() {
		result[name] = ref.String()
	}

	jsonMap, err := json.Marshal(result)
	if err != nil {
		err = errors.Wrap(err, "failed to marshal the map")
		return nil
	}

	return C.CString(string(jsonMap))
}

//export ssbTestingPublishAs
func ssbTestingPublishAs(nick, content string) *C.char {
	var err error
	defer logError("ssbTestingPublishAs", &err)

	iden, err := testKeys.GetNamedKey(nick)
	if err != nil {
		err = errors.Wrap(err, "could not get the identity")
		return nil
	}

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	cmd, err := commands.NewPublishRawAsIdentity([]byte(content), iden)
	if err != nil {
		err = errors.Wrap(err, "error creating a command")
		return nil
	}

	ref, err := service.App.Commands.PublishRawAsIdentity.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "error calling the handler")
		return nil
	}

	return C.CString(ref.String())
}

//export ssbTestingPublishPrivateAs
func ssbTestingPublishPrivateAs(nick, content, recps string) *C.char {
	return nil // publishing private messages is not supported for now
}
