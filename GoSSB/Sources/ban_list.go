package main

import "C"
import (
	"encoding/hex"
	"encoding/json"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
	"github.com/planetary-social/scuttlego/service/domain/bans"
)

// ssbBanListSet overrides the permanent ban list with the provided SHA256
// hashes. The hashes are passed as JSON encoded list of hex-encoded strings.
//
//export ssbBanListSet
func ssbBanListSet(hashes string) bool {
	defer logPanic()

	var err error
	defer logError("ssbBanListSet", &err)

	var unmarshaledHashes []string
	err = json.Unmarshal([]byte(hashes), &unmarshaledHashes)
	if err != nil {
		err = errors.Wrap(err, "json unmarshal error")
		return false
	}

	var convertedHashes []bans.Hash
	for _, unmarshaledHash := range unmarshaledHashes {
		var hashBytes []byte
		hashBytes, err = hex.DecodeString(unmarshaledHash)
		if err != nil {
			err = errors.Wrap(err, "could not decode hash bytes")
			return false
		}

		var h bans.Hash
		h, err = bans.NewHash(hashBytes)
		if err != nil {
			err = errors.Wrap(err, "could not create the hash")
			return false
		}

		convertedHashes = append(convertedHashes, h)
	}

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	cmd, err := commands.NewSetBanList(convertedHashes)
	if err != nil {
		err = errors.Wrap(err, "could not create the command")
		return false
	}

	err = service.App.Commands.SetBanList.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "could not call the command")
		return false
	}

	return true
}
