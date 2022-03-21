// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package names

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"github.com/dgraph-io/badger/v3"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	libbadger "go.cryptoscope.co/margaret/indexes/badger"

	"go.cryptoscope.co/ssb/client"
	refs "go.mindeco.de/ssb-refs"
)

type aboutStore struct {
	kv *badger.DB
}

type AboutInfo struct {
	Name, Description, Image AboutAttribute
}

type AboutAttribute struct {
	Chosen     string
	Prescribed map[string]int
}

var idxKeyPrefix = []byte("idx-abouts")

func (ab aboutStore) ImageFor(ref *refs.FeedRef) (*refs.BlobRef, error) {
	var br refs.BlobRef

	err := ab.kv.View(func(txn *badger.Txn) error {

		addr := ref.Sigil()
		addr += ":"
		addr += ref.Sigil()
		addr += ":image"
		it, err := txn.Get(append(idxKeyPrefix, []byte(addr)...))
		if err != nil {
			return err
		}

		err = it.Value(func(v []byte) error {
			newBlobR, err := refs.ParseBlobRef(string(v))
			if err != nil {
				return err
			}
			br = newBlobR
			return nil
		})
		if err != nil {
			return err
		}
		return nil
	})

	return &br, err
}

func (ab aboutStore) All() (client.NamesGetResult, error) {
	var ngr = make(client.NamesGetResult)
	err := ab.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		for iter.Seek(idxKeyPrefix); iter.ValidForPrefix(idxKeyPrefix); iter.Next() {
			it := iter.Item()
			k := it.Key()

			kWoPrefix := bytes.TrimPrefix(k, idxKeyPrefix)

			if string(kWoPrefix) == "__current_observable" {
				return nil // skip
			}

			parts := strings.Split(string(kWoPrefix), ":")
			if len(parts) != 3 {
				return fmt.Errorf("about.All: illegal key:%q", string(k))
			}

			about := parts[0]
			author := parts[1]
			field := parts[2]

			if string(field) == "name" {
				err := it.Value(func(v []byte) error {
					name := string(v)
					name = strings.TrimPrefix(name, "\"")
					name = strings.TrimSuffix(name, "\"")

					abouts, ok := ngr[about]
					if !ok {
						abouts = make(map[string]string)
						abouts[author] = name
						ngr[about] = abouts
						return nil
					}

					abouts[author] = name

					return nil
				})
				if err != nil {
					return fmt.Errorf("about.All: value of item %q failed: %w", k, err)
				}
			}

		}
		return nil
	})
	return ngr, err
}

func (ab aboutStore) CollectedFor(ref refs.FeedRef) (*AboutInfo, error) {
	addr := append(idxKeyPrefix, []byte(ref.Sigil()+":")...)

	// direct badger magic
	// most of this feels like to direct k:v magic to be honest
	var reduced AboutInfo
	reduced.Name.Prescribed = make(map[string]int)
	reduced.Description.Prescribed = make(map[string]int)
	reduced.Image.Prescribed = make(map[string]int)

	err := ab.kv.View(func(txn *badger.Txn) error {
		iter := txn.NewIterator(badger.DefaultIteratorOptions)
		defer iter.Close()

		for iter.Seek(addr); iter.ValidForPrefix(addr); iter.Next() {
			it := iter.Item()
			k := it.Key()
			k = bytes.TrimPrefix(k, idxKeyPrefix)
			splitted := bytes.Split(k, []byte(":"))

			c, err := refs.ParseFeedRef(string(splitted[1]))
			if err != nil {
				return fmt.Errorf("about: couldnt make author ref from db key: %s: %w", splitted, err)
			}

			err = it.Value(func(v []byte) error {
				var fieldPtr *AboutAttribute
				var foundVal string
				if err := json.Unmarshal(v, &foundVal); err != nil {
					return err
				}

				switch {
				case bytes.HasSuffix(k, []byte(":name")):
					fieldPtr = &reduced.Name
				case bytes.HasSuffix(k, []byte(":description")):
					fieldPtr = &reduced.Description
				case bytes.HasSuffix(k, []byte(":image")):
					fieldPtr = &reduced.Image
				default:
					log.Printf("about debug: %s ", c.Sigil())
					log.Printf("no field for: %q", string(k))
					return nil
				}

				if c.Equal(ref) {
					fieldPtr.Chosen = foundVal
				} else {
					cnt, has := fieldPtr.Prescribed[foundVal]
					if has {
						cnt++
					} else {
						cnt = 1
					}
					fieldPtr.Prescribed[foundVal] = cnt
				}

				return nil
			})
			if err != nil {
				return fmt.Errorf("about: couldnt get idx value: %w", err)
			}

		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("name db lookup failed: %w", err)
	}

	return &reduced, nil
}

const FolderNameAbout = "about"

func (plug *Plugin) OpenSharedIndex(db *badger.DB) (librarian.Index, librarian.SinkIndex) {
	aboutIdx := libbadger.NewIndexWithKeyPrefix(db, 0, idxKeyPrefix)
	update := librarian.NewSinkIndex(updateAboutMessage, aboutIdx)

	plug.about = aboutStore{db}

	return aboutIdx, update
}

func updateAboutMessage(ctx context.Context, seq int64, msgv interface{}, idx librarian.SetterIndex) error {
	var msg refs.Message

	switch tv := msgv.(type) {
	case refs.Message:
		msg = tv
	case error:
		if margaret.IsErrNulled(tv) {
			return nil
		}
		return fmt.Errorf("about(%d): unhandled error type (%T) from index: %w", seq, tv, tv)
	default:
		return fmt.Errorf("about(%d): wrong msgT: %T", seq, msgv)
	}

	var aboutMSG refs.About
	err := json.Unmarshal(msg.ContentBytes(), &aboutMSG)
	if err != nil {
		// nothing to do with this message
		// TODO: git repos and gathering use about messages for their names
		return nil
	}

	// about:from:field
	addr := aboutMSG.About.Sigil()
	addr += ":"
	addr += msg.Author().Sigil()
	addr += ":"

	var val string
	if aboutMSG.Name != "" {
		val = aboutMSG.Name
		if err := idx.Set(ctx, librarian.Addr(addr+"name"), val); err != nil {
			return fmt.Errorf("db/idx about: failed to update name: %w", err)
		}
	}
	if aboutMSG.Description != "" {
		val = aboutMSG.Description
		if err := idx.Set(ctx, librarian.Addr(addr+"description"), val); err != nil {
			return fmt.Errorf("db/idx about: failed to update description: %w", err)
		}
	}
	if aboutMSG.Image != nil {
		val = aboutMSG.Image.Sigil()
		if err := idx.Set(ctx, librarian.Addr(addr+"image"), val); err != nil {
			return fmt.Errorf("db/idx about: failed to update image: %w", err)
		}
	}

	return nil
}
