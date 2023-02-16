package main

import "C"
import (
	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/queries"
	"github.com/planetary-social/scuttlego/service/domain/feeds/message"
	"github.com/planetary-social/scuttlego/service/domain/refs"
)

// ssbGetRawMessage returns a raw message JSON for the specified feed and sequence number. Feed is in the @-notation,
// sequence starts at 1.
//
//export ssbGetRawMessage
func ssbGetRawMessage(feedRef string, seq int64) *C.char {
	defer logPanic()

	var err error
	defer logError("ssbGetRawMessage", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	feed, err := refs.NewFeed(feedRef)
	if err != nil {
		err = errors.Wrap(err, "error creating a feed ref")
		return nil
	}

	sequence, err := message.NewSequence(int(seq))
	if err != nil {
		err = errors.Wrap(err, "error creating a sequence")
		return nil
	}

	query, err := queries.NewGetMessageBySequence(feed, sequence)
	if err != nil {
		err = errors.Wrap(err, "error creating the query")
		return nil
	}

	msg, err := service.App.Queries.GetMessageBySequence.Handle(query)
	if err != nil {
		err = errors.Wrap(err, "error calling the handler")
		return nil
	}

	return C.CString(string(msg.Raw().Bytes()))
}
