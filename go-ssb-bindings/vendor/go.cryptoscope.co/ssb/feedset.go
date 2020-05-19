// SPDX-License-Identifier: MIT

package ssb

import (
	"sync"

	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
)

type strFeedMap map[librarian.Addr]struct{}

type StrFeedSet struct {
	mu  sync.Mutex
	set strFeedMap
}

func NewFeedSet(size int) *StrFeedSet {
	return &StrFeedSet{
		set: make(strFeedMap, size),
	}
}

func (fs *StrFeedSet) AddStored(r *StorageRef) error {
	fs.mu.Lock()
	defer fs.mu.Unlock()

	b, err := r.Marshal()
	if err != nil {
		return errors.Wrap(err, "failed to marshal stored ref")
	}

	fs.set[librarian.Addr(b)] = struct{}{}
	return nil
}

func (fs *StrFeedSet) AddRef(ref *FeedRef) error {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	fs.set[ref.StoredAddr()] = struct{}{}
	return nil
}

func (fs *StrFeedSet) Delete(ref *FeedRef) error {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	delete(fs.set, ref.StoredAddr())
	return nil
}

func (fs *StrFeedSet) Count() int {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	return len(fs.set)
}

func (fs StrFeedSet) List() ([]*FeedRef, error) {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	var lst = make([]*FeedRef, len(fs.set))
	i := 0
	var sr StorageRef
	for feed := range fs.set {
		err := sr.Unmarshal([]byte(feed))
		if err != nil {
			return nil, errors.Wrap(err, "failed to decode map entry")
		}
		lst[i], err = sr.FeedRef()
		if err != nil {
			return nil, errors.Wrap(err, "failed to make ref from map entry")
		}
		// log.Printf("dbg List(%d) %s", i, ref.Ref())
		i++
	}
	return lst, nil
}

func (fs StrFeedSet) Has(ref *FeedRef) bool {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	_, has := fs.set[ref.StoredAddr()]
	return has
}
