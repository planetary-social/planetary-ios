//go:build testing
// +build testing

package main

import "C"

import (
	"encoding/json"
	"path/filepath"
	"verseproj/scuttlegobridge/tests"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
)

//export ssbTestingMakeNamedKey
func ssbTestingMakeNamedKey(name string) int {
	defer logPanic()

	var err error
	defer logError("ssbTestingMakeNamedKey", &err)

	testKeys, err := newTestKeys()
	if err != nil {
		err = errors.Wrap(err, "error creating test keys")
		return -1
	}

	err = testKeys.CreateNamedKey(name)
	if err != nil {
		err = errors.Wrap(err, "error creating named key")
		return -1
	}

	log.WithField("function", "ssbTestingMakeNamedKey").WithField("name", name).Debug("created a key")

	return 0
}

//export ssbTestingAllNamedKeypairs
func ssbTestingAllNamedKeypairs() *C.char {
	defer logPanic()

	var err error
	defer logError("ssbTestingAllNamedKeypairs", &err)

	testKeys, err := newTestKeys()
	if err != nil {
		err = errors.Wrap(err, "error creating test keys")
		return nil
	}

	result := make(map[string]string)

	keys, err := testKeys.ListNamedKeys()
	if err != nil {
		err = errors.Wrap(err, "error listing named keys")
		return nil
	}

	for name, ref := range keys {
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
	defer logPanic()

	var err error
	defer logError("ssbTestingPublishAs", &err)

	testKeys, err := newTestKeys()
	if err != nil {
		err = errors.Wrap(err, "error creating test keys")
		return nil
	}

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
	defer logPanic()

	return nil // publishing private messages is not supported for now
}

func newTestKeys() (*tests.TestKeys, error) {
	repository, err := node.Repository()
	if err != nil {
		return nil, errors.Wrap(err, "could not get the repository")
	}

	storage := tests.NewStorage(filepath.Join(repository, "testing"))
	testKeys := tests.NewTestKeys(storage)
	return testKeys, nil
}
