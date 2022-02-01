// SPDX-License-Identifier: MIT

package ssb

import (
	"fmt"
	"sync"

	librarian "go.cryptoscope.co/margaret/indexes"

	"go.cryptoscope.co/ssb/internal/storedrefs"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

type strFeedMap map[librarian.Addr]struct{}

type StrFeedSet struct {
	mu  *sync.Mutex
	set strFeedMap
}

func NewFeedSet(size int) *StrFeedSet {
	return &StrFeedSet{
		mu:  new(sync.Mutex),
		set: make(strFeedMap, size),
	}
}

func (fs *StrFeedSet) AddRef(ref refs.FeedRef) error {
	fs.mu.Lock()
	defer fs.mu.Unlock()

	fs.set[storedrefs.Feed(ref)] = struct{}{}
	return nil
}

func (fs *StrFeedSet) Delete(ref refs.FeedRef) error {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	delete(fs.set, storedrefs.Feed(ref))
	return nil
}

func (fs *StrFeedSet) Count() int {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	return len(fs.set)
}

func (fs StrFeedSet) List() ([]refs.FeedRef, error) {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	var lst = make([]refs.FeedRef, len(fs.set))

	i := 0

	for feed := range fs.set {
		var sr tfk.Feed
		err := sr.UnmarshalBinary([]byte(feed))
		if err != nil {
			return nil, fmt.Errorf("failed to decode map entry: %w", err)
		}
		// log.Printf("dbg List(%d) %s", i, ref.Ref())
		lst[i], err = sr.Feed()
		if err != nil {
			return nil, fmt.Errorf("failed to decode map entry: %w", err)
		}
		i++
	}
	return lst, nil
}

func (fs StrFeedSet) Has(ref refs.FeedRef) bool {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	_, has := fs.set[storedrefs.Feed(ref)]
	return has
}
