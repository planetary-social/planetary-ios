package main

import (
	"bytes"
	"encoding/json"

	"github.com/pkg/errors"
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

	rv := botStatus{
		Peers: nil,
	}

	for _, peer := range status.Peers {
		rv.Peers = append(rv.Peers, botStatusPeer{
			PublicKey: peer.Identity.PublicKey(),
			Address:   "1.2.3.4:8008",
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

	counts := repoStats{
		Feeds:    status.NumberOfFeeds,
		Messages: status.NumberOfMessages,
	}

	countsBytes, err := json.Marshal(counts)
	if err != nil {
		err = errors.Wrap(err, "failed to marshal json")
		return nil
	}

	return C.CString(string(countsBytes))
}

type botStatus struct {
	Peers []botStatusPeer `json:"peers"`
}

type botStatusPeer struct {
	PublicKey []byte `json:"publicKey"`
	Address   string `json:"address"`
}

type repoStats struct {
	Feeds    int `json:"feeds"`
	Messages int `json:"messages"`
}
