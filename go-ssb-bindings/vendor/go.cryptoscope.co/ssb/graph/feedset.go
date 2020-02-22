// SPDX-License-Identifier: MIT

package graph

import (
	"sync"

	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/ssb"
)

type strFeedMap map[librarian.Addr]struct{}

type StrFeedSet struct {
	sync.Mutex
	set strFeedMap
}

func NewFeedSet(size int) *StrFeedSet {
	return &StrFeedSet{
		set: make(strFeedMap, size),
	}
}

func (fs *StrFeedSet) AddStored(r *ssb.StorageRef) error {
	fs.Lock()
	defer fs.Unlock()

	b, err := r.Marshal()
	if err != nil {
		return errors.Wrap(err, "failed to marshal stored ref")
	}

	fs.set[librarian.Addr(b)] = struct{}{}
	return nil
}

func (fs *StrFeedSet) AddRef(ref *ssb.FeedRef) error {
	fs.Lock()
	defer fs.Unlock()
	fs.set[ref.StoredAddr()] = struct{}{}
	return nil
}

func (fs *StrFeedSet) Delete(ref *ssb.FeedRef) error {
	fs.Lock()
	defer fs.Unlock()
	delete(fs.set, ref.StoredAddr())
	return nil
}

func (fs *StrFeedSet) Count() int {
	fs.Lock()
	defer fs.Unlock()
	return len(fs.set)
}

func (fs *StrFeedSet) List() ([]*ssb.FeedRef, error) {
	fs.Lock()
	defer fs.Unlock()
	var lst = make([]*ssb.FeedRef, len(fs.set))
	i := 0
	var sr ssb.StorageRef
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

func (fs *StrFeedSet) Has(ref *ssb.FeedRef) bool {
	fs.Lock()
	defer fs.Unlock()
	_, has := fs.set[ref.StoredAddr()]
	return has
}
