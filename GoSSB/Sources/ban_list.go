package main

import "C"
import (
	"encoding/hex"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
	"github.com/planetary-social/scuttlego/service/domain/bans"
)

// ssbBanListAdd adds the provided SHA256 hash to a permanent ban list. The hash is
// passed as a hex-encoded string. Passing the same hash multiple times does not result
// in an error.
//
//export ssbBanListAdd
func ssbBanListAdd(hash string) bool {
	var err error
	defer logError("ssbBanListAdd", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	hashBytes, err := hex.DecodeString(hash)
	if err != nil {
		err = errors.Wrap(err, "could not decode hash bytes")
		return false
	}

	h, err := bans.NewHash(hashBytes)
	if err != nil {
		err = errors.Wrap(err, "could not create the hash")
		return false
	}

	cmd, err := commands.NewAddToBanList(h)
	if err != nil {
		err = errors.Wrap(err, "could not create the command")
		return false
	}

	err = service.App.Commands.AddToBanList.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "could not call the command")
		return false
	}

	return true
}

// ssbBanListRemove removes the provided SHA256 hash from a permanent ban list. The hash is
// passed as a hex-encoded string. Removing a hash which is not in the ban list is does not
// result in an error.
//
//export ssbBanListRemove
func ssbBanListRemove(hash string) bool {
	var err error
	defer logError("ssbBanListRemove", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	hashBytes, err := hex.DecodeString(hash)
	if err != nil {
		err = errors.Wrap(err, "could not decode hash bytes")
		return false
	}

	h, err := bans.NewHash(hashBytes)
	if err != nil {
		err = errors.Wrap(err, "could not create the hash")
		return false
	}

	cmd, err := commands.NewRemoveFromBanList(h)
	if err != nil {
		err = errors.Wrap(err, "could not create the command")
		return false
	}

	err = service.App.Commands.RemoveFromBanList.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "could not call the command")
		return false
	}

	return true
}
