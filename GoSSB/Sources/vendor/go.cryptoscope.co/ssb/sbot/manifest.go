// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
)

type namedPlugin struct {
	h    muxrpc.Handler
	name string
}

func (np namedPlugin) Name() string { return np.name }

func (np namedPlugin) Method() muxrpc.Method {
	return muxrpc.Method{np.name}
}

func (np namedPlugin) Handler() muxrpc.Handler {
	return np.h
}

type manifestHandler string

func (manifestHandler) Handled(m muxrpc.Method) bool { return m.String() == "manifest" }

func (manifestHandler) HandleConnect(context.Context, muxrpc.Endpoint) {}

func (h manifestHandler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	err := req.Return(ctx, json.RawMessage(h))
	if err != nil {
		fmt.Println("manifest err", err)
	}
}

func init() {
	manifestMap := make(map[string]interface{})
	err := json.Unmarshal([]byte(manifestBlob), &manifestMap)
	if !json.Valid([]byte(manifestBlob)) || err != nil {
		fmt.Println(err)
		panic("manifestBlob is broken json")
	}

	// remove the whitespaces
	condensed, err := json.Marshal(manifestMap)
	if err != nil {
		panic(err)
	}
	manifestBlob = manifestHandler(condensed)
}

// this is a very simple hardcoded manifest.json dump which oasis' ssb-client expects to do it's magic.
var manifestBlob manifestHandler = `
{
	"manifest": "sync",

	"get": "async",
	"createFeedStream": "source",
	"createUserStream": "source",

	"createSequenceStream": "source",
	"createLogStream": "source",
	"messagesByType": "source",
	"createHistoryStream": "source",

	"ebt": { "replicate": "duplex" },

	"partialReplication":{
		"getSubset": "source",
	 	"getTangle": "async"
	},

	"private": {
		"publish": "async",
		"read":"source"
	},

	"tangles": {
      "thread": "source"
	},

    "names": {
        "get": "async",
        "getImageFor": "async",
        "getSignifier": "async"
    },

	"friends": {
	  "hops": "source",
	  "isFollowing": "async",
	  "isBlocking": "async"
	},

	"tunnel": {
		"connect": "duplex",
		"isRoom": "async"
	},

	"publish": "async",
	"whoami": "sync",
	"status": "sync",
	
	"conn": {
		"replicate": "async",
		"connect": "async",
		"disconnect": "async",
		"dialViaRoom": "async"
	},
	
	"gossip": {
	  "connect": "async",
	  "ping": "duplex"
	},

	"replicate": {
	  "upto": "source"
	},

    "groups": {
      "create":"async",
      "publishTo":"async"
    },

	"blobs": {
	  "get": "source",

	  "add": "sink",
	  "rm": "async",
	  "ls": "source",
	  "has": "async",
	  "size": "async",

	  "want": "async",

	  "createWants": "source"
	},

	"invite": {
		"create": "async",
		"use": "async"
	}
  }
  `
