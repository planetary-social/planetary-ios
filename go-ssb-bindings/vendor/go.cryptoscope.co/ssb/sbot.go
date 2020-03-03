// SPDX-License-Identifier: MIT

package ssb

import (
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
)

type Publisher interface {
	margaret.Log

	// Publish is a utility wrapper around append which returns the new message reference key
	Publish(content interface{}) (*MessageRef, error)
}

type Getter interface {
	Get(MessageRef) (Message, error)
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

type Statuser interface {
	Status() (Status, error)
}

type PeerStatus struct {
	Addr  string
	Since string
}
type Status struct {
	PID   int // process id of the bot
	Peers []PeerStatus
	Blobs interface{}
	Root  margaret.Seq
}

type ContentNuller interface {
	NullContent(feed *FeedRef, seq uint) error
}
