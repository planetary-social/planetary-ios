// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.cryptoscope.co/luigi"
	refs "go.mindeco.de/ssb-refs"

	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/repo"
)

// NullFeed overwrites all the entries from ref in repo with zeros
func (s *Sbot) NullFeed(ref refs.FeedRef) error {
	ctx := context.Background()

	feedAddr := storedrefs.Feed(ref)
	userSeqs, err := s.Users.Get(feedAddr)
	if err != nil {
		return fmt.Errorf("NullFeed: failed to open log for feed argument: %w", err)
	}

	src, err := userSeqs.Query()
	if err != nil {
		return fmt.Errorf("NullFeed: failed create user seqs query: %w", err)
	}

	for {
		v, err := src.Next(ctx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			return err
		}
		seq, ok := v.(int64)
		if !ok {
			return fmt.Errorf("NullFeed: not a sequence from userlog query")
		}
		err = s.ReceiveLog.Null(seq)
		if err != nil {
			return err
		}
	}

	err = s.Users.Delete(feedAddr)
	if err != nil {
		return fmt.Errorf("NullFeed: error while deleting feed from userFeeds index: %w", err)
	}

	err = s.GraphBuilder.DeleteAuthor(ref)
	if err != nil {
		return fmt.Errorf("NullFeed: error while deleting feed from graph index: %w", err)
	}

	// delete my ebt state
	// TODO: just remove that single feed
	sfn, err := s.ebtState.StateFileName(s.KeyPair.ID())
	if err != nil {
		return fmt.Errorf("NullFeed: error while deleting ebt state file: %w", err)
	}
	os.Remove(sfn)

	if !s.disableNetwork {
		s.verifyRouter.CloseSink(ref)
	}

	return nil
}

// Drop indicies deletes the following folders of the indexes.
// TODO: check that sbot isn't running?
func DropIndicies(r repo.Interface) error {

	// drop indicies
	var mlogs = []string{
		multilogs.IndexNameFeeds,
		// multilogs.IndexNameTypes,
		multilogs.IndexNamePrivates,
	}
	for _, i := range mlogs {
		dbPath := r.GetPath(repo.PrefixMultiLog, i)
		err := os.RemoveAll(dbPath)
		if err != nil {
			err = fmt.Errorf("mkdir error for %q: %w", dbPath, err)
			return err
		}
	}
	// TODO: shared mlog
	// var badger = []string{
	// 	indexes.FolderNameContacts,
	// }
	// for _, i := range badger {
	// 	dbPath := r.GetPath(repo.PrefixIndex, i)
	// 	err := os.RemoveAll(dbPath)
	// 	if err != nil {
	// 		err = fmt.Errorf("mkdir error for %q: %w", dbPath, err)
	// 		return err
	// 	}
	// }
	log.Println("removed index folders")
	return nil
}

func RebuildIndicies(path string) error {
	fi, err := os.Stat(path)
	if err != nil {
		err = fmt.Errorf("RebuildIndicies: failed to open sbot: %w", err)
		return err
	}

	if !fi.IsDir() {
		return fmt.Errorf("RebuildIndicies: repo path is not a directory")
	}

	// rebuilding indexes
	sbot, err := New(
		DisableNetworkNode(),
		WithRepoPath(path),
		DisableLiveIndexMode(),
	)
	if err != nil {
		err = fmt.Errorf("failed to open sbot: %w", err)
		return err
	}

	// TODO: not sure if I should hook this signal here..
	c := make(chan os.Signal)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		sbot.Shutdown()

		time.Sleep(5 * time.Second)

		err := sbot.Close()
		log.Println("sbot closed:", err)

		time.Sleep(5 * time.Second)
		os.Exit(0)
	}()

	start := time.Now()
	log.Println("started sbot for re-indexing")
	err = sbot.Close()
	log.Println("re-indexing took:", time.Since(start))
	if err != nil {
		return fmt.Errorf("RebuildIndicies: failed to close sbot: %w", err)
	}
	return nil
}
