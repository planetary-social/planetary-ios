// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package graph

import (
	"context"
	"fmt"

	"github.com/zeebo/bencode"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	"go.mindeco.de/ssb-refs/tfk"

	"github.com/ssb-ngi-pointer/go-metafeed"
	"github.com/ssb-ngi-pointer/go-metafeed/metamngmt"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message/legacy"
	refs "go.mindeco.de/ssb-refs"
)

type idxRelationState uint

const (
	idxRelValueNone idxRelationState = iota
	idxRelValueFollowing
	idxRelValueBlocking
	idxRelValueMetafeed
)

func (b *BadgerBuilder) updateAnnouncement(ctx context.Context, seq int64, val interface{}, idx librarian.SetterIndex) error {
	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()

	if nulled, ok := val.(error); ok {
		if margaret.IsErrNulled(nulled) {
			return nil
		}
		return nulled
	}

	msg, ok := val.(refs.Message)
	if !ok {
		err := fmt.Errorf("graph/idx: invalid msg value %T", val)
		level.Warn(b.log).Log("msg", "announcement eval failed", "reason", err)
		return err
	}

	announceMsg, ok := legacy.VerifyMetafeedAnnounce(msg.ContentBytes(), msg.Author(), nil) // TODO: hmac support
	if !ok {
		return nil // skip invalid messages
	}

	addr := storedrefs.Feed(msg.Author())

	tfkRef, err := tfk.FeedFromRef(announceMsg.Metafeed)
	if err != nil {
		return fmt.Errorf("db/idx announcements: failed to turn metafeed value into binary: %w", err)
	}

	err = idx.Set(ctx, addr, tfkRef)
	if err != nil {
		return fmt.Errorf("db/idx announcements: failed to update index %+v: %w", announceMsg, err)
	}

	b.cachedGraph = nil
	// TODO: patch existing graph instead of invalidating
	return nil
}

func (b *BadgerBuilder) OpenAnnouncementIndex() (librarian.SeqSetterIndex, librarian.SinkIndex) {
	if b.idxSinkAnnouncements == nil {
		b.idxSinkAnnouncements = librarian.NewSinkIndex(b.updateAnnouncement, b.idx)
	}
	return b.idx, b.idxSinkAnnouncements
}

func (b *BadgerBuilder) updateContacts(ctx context.Context, seq int64, val interface{}, idx librarian.SetterIndex) error {
	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()

	if nulled, ok := val.(error); ok {
		if margaret.IsErrNulled(nulled) {
			return nil
		}
		return nulled
	}

	abs, ok := val.(refs.Message)
	if !ok {
		err := fmt.Errorf("graph/idx: invalid msg value %T", val)
		level.Warn(b.log).Log("msg", "contact eval failed", "reason", err)
		return err
	}

	var c refs.Contact
	err := c.UnmarshalJSON(abs.ContentBytes())
	if err != nil {
		// just ignore invalid messages, nothing to do with them (unless you are debugging something)
		//level.Warn(b.log).Log("msg", "skipped contact message", "reason", err)
		return nil
	}

	addr := storedrefs.Feed(abs.Author())
	addr += storedrefs.Feed(c.Contact)
	switch {
	case c.Following:
		err = idx.Set(ctx, addr, idxRelValueFollowing)
	case c.Blocking:
		err = idx.Set(ctx, addr, idxRelValueBlocking)
	default:
		err = idx.Set(ctx, addr, idxRelValueNone)
		// cryptix: not sure why this doesn't work
		// it also removes the node if this is the only follow from that peer
		// 3 state handling seems saner
		// err = idx.Delete(ctx, librarian.Addr(addr))
	}
	if err != nil {
		return fmt.Errorf("db/idx contacts: failed to update index. %+v: %w", c, err)
	}

	b.cachedGraph = nil
	// TODO: patch existing graph instead of invalidating
	return nil
}

func (b *BadgerBuilder) OpenContactsIndex() (librarian.SeqSetterIndex, librarian.SinkIndex) {
	if b.idxSinkContacts == nil {
		b.idxSinkContacts = librarian.NewSinkIndex(b.updateContacts, b.idx)
	}
	return b.idx, b.idxSinkContacts
}

func (b *BadgerBuilder) updateMetafeeds(ctx context.Context, seq int64, val interface{}, idx librarian.SetterIndex) error {
	b.cacheLock.Lock()
	defer b.cacheLock.Unlock()

	if nulled, ok := val.(error); ok {
		if margaret.IsErrNulled(nulled) {
			return nil
		}
		return nulled
	}

	msg, ok := val.(refs.Message)
	if !ok {
		err, ok := val.(error)
		if ok && margaret.IsErrNulled(err) {
			return nil
		}
		return fmt.Errorf("index/get: unexpected message type: %T", val)
	}

	// skip invalid feeds
	if msg.Author().Algo() != refs.RefAlgoFeedBendyButt {
		return nil
	}

	msgLogger := log.With(b.log,
		"event", "metafeed update",
		"msg-key", msg.Key().ShortSigil(),

		// debugging
		"author", msg.Author().String(),
		"seq", msg.Seq(),
	)

	var bencoded []bencode.RawMessage
	err := bencode.DecodeBytes(msg.ContentBytes(), &bencoded)
	if err != nil {
		level.Warn(msgLogger).Log("warning", "content array unmarshal failed", "err", err)
		return nil
	}

	if n := len(bencoded); n != 2 {
		level.Warn(msgLogger).Log("warning", "index is not an array with length 2", "len", n)
		return nil
	}

	var justTheType metamngmt.Typed
	err = bencode.DecodeBytes(bencoded[0], &justTheType)
	if err != nil || justTheType.Type == "" {
		level.Warn(msgLogger).Log("warning", "content has no or broken type field", "err", err)
		return nil
	}

	level.Debug(msgLogger).Log("processing-rxseq", seq)

	addr := storedrefs.Feed(msg.Author())

	switch justTheType.Type {
	case "metafeed/add/existing":
		var addMsg metamngmt.AddExisting
		err = metafeed.VerifySubSignedContent(msg.ContentBytes(), &addMsg)
		if err != nil {
			level.Warn(msgLogger).Log("warning", "sub-signature is invalid", "err", err)
			return nil
		}

		if !addMsg.MetaFeed.Equal(msg.Author()) {
			level.Warn(msgLogger).Log("warning", "content is not about the author of the metafeed", "content feed", addMsg.MetaFeed.ShortSigil(), "meta author", msg.Author().ShortSigil())
			// skip invalid add message
			return nil
		}
		addr += storedrefs.Feed(addMsg.SubFeed)

		level.Info(msgLogger).Log("adding", addMsg.SubFeed.String())
		err = idx.Set(ctx, addr, idxRelValueMetafeed)

	case "metafeed/add/derived":
		var addMsg metamngmt.AddDerived
		err = metafeed.VerifySubSignedContent(msg.ContentBytes(), &addMsg)
		if err != nil {
			level.Warn(msgLogger).Log("warning", "sub-signature is invalid", "err", err)
			return nil
		}

		if !addMsg.MetaFeed.Equal(msg.Author()) {
			level.Warn(msgLogger).Log("warning", "content is not about the author of the metafeed", "content feed", addMsg.MetaFeed.ShortSigil(), "meta author", msg.Author().ShortSigil())
			// skip invalid add message
			return nil
		}
		addr += storedrefs.Feed(addMsg.SubFeed)

		level.Info(msgLogger).Log("adding", addMsg.SubFeed.ShortSigil())
		err = idx.Set(ctx, addr, idxRelValueMetafeed)

	case "metafeed/tombstone":
		var tMsg metamngmt.Tombstone
		err = metafeed.VerifySubSignedContent(msg.ContentBytes(), &tMsg)
		if err != nil {
			level.Warn(msgLogger).Log("warning", "sub-signature is invalid", "err", err)
			return nil
		}

		if !tMsg.MetaFeed.Equal(msg.Author()) {
			level.Warn(msgLogger).Log("warning", "content is not about the author of the metafeed", "content feed", tMsg.MetaFeed.ShortSigil(), "meta author", msg.Author().ShortSigil())
			// skip invalid add message
			return nil
		}
		addr += storedrefs.Feed(tMsg.SubFeed)

		level.Info(msgLogger).Log("removing", tMsg.SubFeed.ShortSigil())
		err = idx.Set(ctx, addr, idxRelValueNone)

	default:
		level.Warn(msgLogger).Log("warning", "unhandeled message type", "type", justTheType.Type)
	}

	if err != nil {
		return fmt.Errorf("failed to update metafeed index with message %s: %w", msg.Key().String(), err)
	}

	return nil

}

func (b *BadgerBuilder) OpenMetafeedsIndex() (librarian.SeqSetterIndex, librarian.SinkIndex) {
	if b.idxSinkMetaFeeds == nil {
		b.idxSinkMetaFeeds = librarian.NewSinkIndex(b.updateMetafeeds, b.idx)
	}
	return b.idx, b.idxSinkMetaFeeds
}
