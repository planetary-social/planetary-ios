// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package ssb

import (
	"fmt"

	refs "go.mindeco.de/ssb-refs"
)

// ErrSubfeedNotActive is returned when trying to publish or tombstone an invalid feed
var ErrSubfeedNotActive = fmt.Errorf("ssb: subfeed not marked as active")

// MetaFeeds allows managing and publishing to subfeeds of a metafeed.
type MetaFeeds interface {
	// CreateSubFeed derives a new keypair, stores it in the keystore and publishes a `metafeed/add/derived` message on the metafeed it's mounted on.
	// It takes purpose which will be published and added to the keystore, too.
	// The subfeed will use the pased format.
	CreateSubFeed(mount refs.FeedRef, purpose string, format refs.RefAlgo, metadata ...map[string]string) (refs.FeedRef, error)

	// TombstoneSubFeed removes the keypair from the store and publishes a `metafeed/tombstone` message to the metafeed it's mounted on.
	// Afterwards the referenced feed is unusable.
	TombstoneSubFeed(mount refs.FeedRef, subfeed refs.FeedRef) error

	// ListSubFeeds returns a list of all _active_ subfeeds of the specified metafeed.
	ListSubFeeds(whose refs.FeedRef) ([]SubfeedListEntry, error)

	// Publish works like normal `Sbot.Publish()` but takes an additional feed reference,
	// which specifies the subfeed on which the content should be published.
	Publish(as refs.FeedRef, content interface{}) (refs.Message, error)

	RegisterIndex(mountingMetafeed, contentFeed refs.FeedRef, msgType string) error
	TombstoneIndex(mountingMetafeed, contentFeed refs.FeedRef, msgType string) error

	GetOrCreateIndex(mount, contentFeed refs.FeedRef, purpose, msgType string) (refs.FeedRef, error)
}

type SubfeedListEntry struct {
	Feed refs.FeedRef
	Seq  int64
}

type MetadataQuery struct {
	Private bool         `json:"private"`
	Author  refs.FeedRef `json:"author"`
	Type    string       `json:"type"`
}

type IndexedMessage struct {
	Type    string `json:"type"`
	Indexed struct {
		Sequence int64           `json:"sequence"`
		Key      refs.MessageRef `json:"key"`
	} `json:"indexed"`
}

type IndexListEntry struct {
	Metadata MetadataQuery // the metadata (author of the indexed messages, the message types indexed by this index)
	Index    refs.FeedRef  // the id of the index
}

func (entry SubfeedListEntry) String() string {
	return fmt.Sprintf("%s (%d)", entry.Feed.ShortSigil(), entry.Seq)
}

// IndexFeedManager allows setting up index feeds
type IndexFeedManager interface {
	// Register registers an index feed for messages of msgType on a corresponding feed contentFeed.
	// contentFeed the feed where messages are read from
	// output is the index feed where the index messages are published to
	Register(indexFeed, contentFeed refs.FeedRef, msgType string) error
	Deregister(refs.FeedRef) (bool, error)

	Process(refs.Message) (refs.FeedRef, IndexedMessage, error)

	List() ([]IndexListEntry, error)
	ListByType(msgtype string) ([]IndexListEntry, error)
}
