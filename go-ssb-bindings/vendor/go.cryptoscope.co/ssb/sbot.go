// SPDX-License-Identifier: MIT

package ssb

import (
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

type Publisher interface {
	margaret.Log

	// Publish is a utility wrapper around append which returns the new message reference key
	Publish(content interface{}) (refs.MessageRef, error)
}

type Getter interface {
	Get(refs.MessageRef) (refs.Message, error)
}

type MultiLogGetter interface {
	GetMultiLog(name string) (multilog.MultiLog, bool)
}

type SimpleIndexGetter interface {
	GetSimpleIndex(name string) (librarian.Index, bool)
}

type Indexer interface {
	MultiLogGetter
	SimpleIndexGetter
	GetIndexNamesSimple() []string
	GetIndexNamesMultiLog() []string
}

// Replicator is used to tell the bot which feeds to copy from other peers and which ones to block
type Replicator interface {
	Replicate(refs.FeedRef)
	DontReplicate(refs.FeedRef)
	Block(refs.FeedRef)
	Unblock(refs.FeedRef)

	Lister() ReplicationLister
}

// ReplicationLister is used by the executing part to get the lists
// TODO: maybe only pass read-only/copies or slices down
type ReplicationLister interface {
	Authorizer
	ReplicationList() *StrFeedSet
	BlockList() *StrFeedSet
}

// Statuser returns status information about the bot, like how many open connections it has (see type Status for more)
type Statuser interface {
	Status() (Status, error)
}

type PeerStatus struct {
	Addr  string
	Since string
}
type Status struct {
	PID      int // process id of the bot
	Peers    []PeerStatus
	Blobs    []BlobWant
	Root     int64
	Indicies IndexStates
}

type IndexStates []IndexState

type IndexState struct {
	Name  string
	State string
}

type ContentNuller interface {
	NullContent(feed refs.FeedRef, seq uint) error
}

// this is one message of replicate.upto
// also handy to talk about the (latest) state of a single feed
type ReplicateUpToResponse struct {
	ID       refs.FeedRef `json:"id"`
	Sequence int64        `json:"sequence"`
}

var _ margaret.Seqer = ReplicateUpToResponse{}

func (upto ReplicateUpToResponse) Seq() int64 {
	return upto.Sequence
}

// FeedsWithSequnce returns a source that emits one ReplicateUpToResponse per stored feed in feedIndex
// TODO: make cancelable and with no RAM overhead when only partially used (iterate on demand)
func FeedsWithSequnce(feedIndex multilog.MultiLog) (luigi.Source, error) {
	storedFeeds, err := feedIndex.List()
	if err != nil {
		return nil, fmt.Errorf("feedSrc: did not get user list: %w", err)
	}

	var feedsWithSeqs []interface{}

	for i, author := range storedFeeds {
		var sr tfk.Feed
		err := sr.UnmarshalBinary([]byte(author))
		if err != nil {
			return nil, fmt.Errorf("feedSrc(%d): invalid storage ref: %w", i, err)
		}
		authorRef, err := sr.Feed()
		if err != nil {
			return nil, fmt.Errorf("feedSrc(%d): failed to get feed: %w", i, err)
		}

		subLog, err := feedIndex.Get(author)
		if err != nil {
			return nil, fmt.Errorf("feedSrc(%d): did not load sublog: %w", i, err)
		}

		elem := ReplicateUpToResponse{
			ID:       authorRef,
			Sequence: subLog.Seq() + 1,
		}
		feedsWithSeqs = append(feedsWithSeqs, elem)
	}
	src := luigi.SliceSource(feedsWithSeqs)
	return &src, nil
}
