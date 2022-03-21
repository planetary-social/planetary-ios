// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

func newIndexFeedManager(storagePath string) (ssb.IndexFeedManager, error) {
	m := indexFeedManager{indexes: make(map[string]refs.FeedRef), storagePath: storagePath}

	// load previous registered indexes (if any)
	err := m.load()
	if err != nil {
		return indexFeedManager{}, fmt.Errorf("indexfeedmanager: failed to load stored indexes (%w)", err)
	}

	return m, nil
}

type indexFeedManager struct {
	// registered indexes
	indexes     map[string]refs.FeedRef
	storagePath string
}

const indexSeparator = ":::"

func constructIndexKey(author refs.FeedRef, msgType string) string {
	return author.String() + indexSeparator + msgType
}

// Method Register keeps track of index feeds so that whenever we publish a new message we also correspondingly publish
// an index message into the registered index feed.
func (manager indexFeedManager) Register(indexFeed, contentFeed refs.FeedRef, msgType string) error {
	// check if the index for this author+type tuple has already been registered
	indexId := constructIndexKey(contentFeed, msgType)
	// an index feed for {contentFeed, msgType} was already registered
	if _, exists := manager.indexes[indexId]; exists {
		return nil
	}

	manager.indexes[indexId] = indexFeed
	err := manager.store()
	if err != nil {
		return err
	}
	return nil
}

// Strategy: persist (as file on disk) which indexes have been created, storing contentFeed+indexFeed+type;
// * contentFeed: the author's pubkey,
// * indexFeed: index feed you publish to, as identified by its SSB1 feedref
// * type: e.g. contact, about
//
// Currently, this is stored all in one file
func (manager indexFeedManager) store() error {
	data, err := json.MarshalIndent(manager.indexes, "", "  ")
	if err != nil {
		return fmt.Errorf("indexFeedManager marshaling indexes state failed (%w)", err)
	}

	err = os.MkdirAll(manager.storagePath, 0700)
	if err != nil {
		return fmt.Errorf("indexFeedManager mkdir failed (%w)", err)
	}

	indexpath := filepath.Join(manager.storagePath, "indexes.json")
	err = os.WriteFile(indexpath, data, 0700)
	if err != nil {
		return fmt.Errorf("indexFeedManager write indexes file failed (%w)", err)
	}
	return nil
}

func (manager *indexFeedManager) load() error {
	indexpath := filepath.Join(manager.storagePath, "indexes.json")
	// indexes have not yet been persisted to disk
	_, err := os.Stat(indexpath)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}

	data, err := os.ReadFile(indexpath)
	if err != nil {
		return fmt.Errorf("indexFeedManager read indexes file failed (%w)", err)
	}

	err = json.Unmarshal(data, &manager.indexes)
	if err != nil {
		return fmt.Errorf("indexFeedManager unmarshal failed (%w)", err)
	}
	return nil
}

// Method Deregister removes a previously tracked index feed.
// Returns true if feed was found && removed (false if not found)
func (manager indexFeedManager) Deregister(indexFeed refs.FeedRef) (bool, error) {
	var soughtKey string
	for key, feed := range manager.indexes {
		// found the index
		if feed.Equal(indexFeed) {
			soughtKey = key
			break
		}
	}
	if soughtKey != "" {
		delete(manager.indexes, soughtKey)
		err := manager.store()
		if err != nil {
			return false, err
		}
		return true, nil
	}
	return false, nil
}

// Process looks through all the registered indexes and publishes messages accordingly
func (manager indexFeedManager) Process(m refs.Message) (refs.FeedRef, ssb.IndexedMessage, error) {
	// we only index (and therefor process, and unmarshal) classic messages
	algo := m.Key().Algo()
	if algo != refs.RefAlgoMessageSSB1 {
		return refs.FeedRef{}, ssb.IndexedMessage{}, nil
	}

	// creates index messages after actual messages have been published
	var typed struct {
		Type string
	}

	// (2021-10-07) revisit decoding of private messages more elegantly
	err := json.Unmarshal(m.ContentBytes(), &typed)
	if err != nil {
		var contentIsString string
		// try to unmarshal a private message, if it works then we just skip this message
		stringerr := json.Unmarshal(m.ContentBytes(), &contentIsString)
		if stringerr == nil {
			return refs.FeedRef{}, ssb.IndexedMessage{}, nil
		}
		return refs.FeedRef{}, ssb.IndexedMessage{}, err
	}

	// do nothing (reasons for no type is usually encrypted messages)
	if typed.Type == "" {
		return refs.FeedRef{}, ssb.IndexedMessage{}, nil
	}

	// lookup correct index
	idxKey := constructIndexKey(m.Author(), typed.Type)
	pubkey, has := manager.indexes[idxKey] // use pubkey to later get publisher
	if !has {
		return refs.FeedRef{}, ssb.IndexedMessage{}, nil
	}

	content := ssb.IndexedMessage{Type: "indexed"}
	content.Indexed.Sequence = m.Seq()
	content.Indexed.Key = m.Key()

	return pubkey, content, nil
}

func (manager indexFeedManager) List() ([]ssb.IndexListEntry, error) {
	return manager.ListByType("")
}

func (manager indexFeedManager) ListByType(msgType string) ([]ssb.IndexListEntry, error) {
	indexlist := make([]ssb.IndexListEntry, len(manager.indexes))
	var i int
	for key, indexfeed := range manager.indexes {
		parts := strings.Split(key, indexSeparator)
		if len(parts) != 2 {
			return []ssb.IndexListEntry{}, fmt.Errorf("ListByType: index key was supposed to be len 2, but wasn't")
		}
		authorString := parts[0]
		foundType := parts[1]

		// if msgType specified, and the current index wasn't indexing the sought msgType then skip to next one
		if msgType != "" && foundType != msgType {
			continue
		}

		author, err := refs.ParseFeedRef(authorString)
		if err != nil {
			return nil, fmt.Errorf("ListByType: failed to parse feed ref %s (%w)", parts[0], err)
		}
		indexlist[i].Metadata = ssb.MetadataQuery{Author: author, Type: foundType}
		indexlist[i].Index = indexfeed

		i++
	}
	// return the slice of indexlist that's actually used (if filtering by a type, it's likely that i < len(manager.indexes))
	return indexlist[:i], nil
}
