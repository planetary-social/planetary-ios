package main

import (
	"bytes"
	"encoding/json"
	"fmt"

	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
)

import "C"

//export ssbBotStatus
func ssbBotStatus() *C.char {
	defer logPanic()

	var err error
	defer logError("ssbBotStatus", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	status, err := service.App.Queries.Status.Handle()
	if err != nil {
		err = errors.Wrap(err, "could not execute the query")
		return nil
	}

	rv := ssb.Status{ // todo return something else, cleanup the interface
		PID:      1,
		Peers:    nil,
		Blobs:    make([]ssb.BlobWant, 0),
		Root:     1,
		Indicies: nil,
	}

	for _, peer := range status.Peers {
		rv.Peers = append(rv.Peers, ssb.PeerStatus{
			Addr:  fmt.Sprintf("net:1.2.3.4:8008~shs:%s", peer.Identity.String()), // todo change this so we just return the key
			Since: "since_is_not_supported",
		})
	}

	var buf bytes.Buffer
	err = json.NewEncoder(&buf).Encode(rv)
	if err != nil {
		err = errors.Wrap(err, "failed to encode result")
		return nil
	}

	return C.CString(buf.String())
}

//export ssbOpenConnections
func ssbOpenConnections() uint {
	defer logPanic()

	var err error
	defer logError("ssbOpenConnections", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return 0
	}

	status, err := service.App.Queries.Status.Handle()
	if err != nil {
		err = errors.Wrap(err, "could not execute the query")
		return 0
	}

	return uint(len(status.Peers))
}

//export ssbRepoStats
func ssbRepoStats() *C.char {
	defer logPanic()

	var err error
	defer logError("ssbRepoStats", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	status, err := service.App.Queries.Status.Handle()
	if err != nil {
		err = errors.Wrap(err, "could not execute the query")
		return nil
	}

	counts := repoCounts{
		Feeds:    status.NumberOfFeeds,
		Messages: int64(status.NumberOfMessages),
		LastHash: "last_hash_is_not_supported",
	}

	countsBytes, err := json.Marshal(counts)
	if err != nil {
		err = errors.Wrap(err, "failed to marshal json")
		return nil
	}

	return C.CString(string(countsBytes))
}

type repoCounts struct {
	Feeds    int    `json:"feeds"`
	Messages int64  `json:"messages"`
	LastHash string `json:"lastHash"`
}
