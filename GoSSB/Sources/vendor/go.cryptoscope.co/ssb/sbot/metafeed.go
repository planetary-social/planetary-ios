// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"

	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"

	"github.com/ssb-ngi-pointer/go-metafeed"
	"github.com/ssb-ngi-pointer/go-metafeed/metakeys"
	"github.com/ssb-ngi-pointer/go-metafeed/metamngmt"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/mutil"
	"go.cryptoscope.co/ssb/internal/slp"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/private/keys"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

// WithMetaFeedMode enables metafeed support.
// It switches the default keypair to bendybutt and initializes the MetaFeed API of the Sbot.
func WithMetaFeedMode(enable bool) Option {
	return func(s *Sbot) error {
		s.enableMetafeeds = enable
		return nil
	}
}

type metaFeedsService struct {
	rxLog        margaret.Log
	indexManager ssb.IndexFeedManager
	users        multilog.MultiLog
	keys         *keys.Store

	hmacSecret *[32]byte
}

func newMetaFeedService(rxLog margaret.Log, indexManager ssb.IndexFeedManager, users multilog.MultiLog, keyStore *keys.Store, keypair ssb.KeyPair, hmacSecret *[32]byte) (*metaFeedsService, error) {
	metaKeyPair, ok := keypair.(metakeys.KeyPair)
	if !ok {
		return nil, fmt.Errorf("not a metafeed keypair: %T", keypair)
	}
	if err := checkOrStoreKeypair(keyStore, metaKeyPair); err != nil {
		return nil, fmt.Errorf("failed to initialize keystore with root keypair: %w", err)
	}

	return &metaFeedsService{
		rxLog:        rxLog,
		indexManager: indexManager,
		users:        users,
		hmacSecret:   hmacSecret,

		keys: keyStore,
	}, nil
}

// Get a message (type `metafeed/add/derived`) from a root metafeed at the specified sequence
func (s metaFeedsService) getMsgAtSeq(mfId refs.FeedRef, seq int64) (metamngmt.AddDerived, error) {
	var empty metamngmt.AddDerived

	msgSeqs, err := s.users.Get(storedrefs.Feed(mfId))
	if err != nil {
		return empty, err
	}

	msgs := mutil.Indirect(s.rxLog, msgSeqs)

	// seq is the sequence on the metafeed that the subfeed was created at
	flatValue, err := msgs.Get(seq - 1) // sequences are stored in a 0-indexed fashion: subtract 1!
	if err != nil {
		return empty, fmt.Errorf("getMsgAtSeq: failed to get msg seq@%d (%w)", seq, err)
	}

	// massage into compatible form
	msg := flatValue.(refs.Message)

	// unpack message contents
	var addMsg metamngmt.AddDerived
	err = metafeed.VerifySubSignedContent(msg.ContentBytes(), &addMsg)
	if err != nil {
		return empty, fmt.Errorf("getMsgAtSeq: failed to unpack addDerived contents (%w", err)
	}
	return addMsg, nil
}

// The purpose of method RegisterIndex is to enable indexing of messages created by a given feed, of the given type. To do
// that, we have to get (or create!) an index feed on which to publish the index messages.
func (s metaFeedsService) RegisterIndex(mfId, contentFeed refs.FeedRef, msgType string) error {
	newIndex, err := s.GetOrCreateIndex(mfId, contentFeed, "index", msgType)
	if err != nil {
		return fmt.Errorf("failed to get/create index (%w)", err)
	}

	err = s.indexManager.Register(newIndex, contentFeed, msgType)
	if err != nil {
		return err
	}
	return nil
}

func (s metaFeedsService) getIndexesFeed (mfId refs.FeedRef) (refs.FeedRef, error) {
	var err error
	var indexesFeedRef, empty refs.FeedRef
	var indexesFeeds []refs.FeedRef

	// list the various subfeeds under the root metafeed mfId
	subfeedList, err := s.ListSubFeeds(mfId)
	if err != nil {
		return empty, fmt.Errorf("failed to list subfeeds for root mf (%w)", err)
	}
	for _, entry := range subfeedList {
		// sequence at 0 indicates a sentinel value (the first message always has sequence number 1)
		if entry.Seq == 0 {
			continue
		}
		metafeedDerivedMsg, err := s.getMsgAtSeq(mfId, entry.Seq)
		if err != nil {
			return empty, fmt.Errorf("failed to get AddDerivedMsg at seq %d in metafeed %s (%w)", entry.Seq, mfId.ShortSigil(), err)
		}
		if metafeedDerivedMsg.FeedPurpose == "indexes" {
			indexesFeeds = append(indexesFeeds, metafeedDerivedMsg.SubFeed)
		}
	}

	// we need to create the indexes feed
	if len(indexesFeeds) == 0 {
		indexesFeedRef, err = s.CreateSubFeed(mfId, "indexes", refs.RefAlgoFeedBendyButt)
		if err != nil {
			return empty, fmt.Errorf("failed to create `indexes` feed (%w)", err)
		}
	} else { // we have one or more indexes feeds
		// we only have one, that's easy :')
		if len(indexesFeeds) == 1 {
			indexesFeedRef = indexesFeeds[0]
		} else {
			// we have multiple indexes feeds hmm..
			return empty, fmt.Errorf("there were multiple indexes feeds (feedpurpose: `indexes`)")
		}
	}
	return indexesFeedRef, nil
}

func (s metaFeedsService) TombstoneIndex(mfId, contentFeed refs.FeedRef, msgType string) error {
	index, err := s.GetOrCreateIndex(mfId, contentFeed, "index", msgType)
	if err != nil {
		return fmt.Errorf("index for feed %s of type %s mounted on %s not found (%w)", contentFeed, msgType, mfId, err)
	}
	_, err = s.indexManager.Deregister(index)
	if err != nil {
		return fmt.Errorf("tombstone index: failed to deregister index (%w)", err)
	}
	indexesFeed, err := s.getIndexesFeed(mfId)
	if err != nil {
		return fmt.Errorf("tombstone index: failed to get `indexes` subfeed (%w)", err)
	}
	err = s.TombstoneSubFeed(indexesFeed, index)
	if err != nil {
		return fmt.Errorf("tombstone index: failed to tombstone index using TombstoneSubfed (%w)", err)
	}
	return nil
}

// Get or create an index feed for a particular message type and author contentFeed on a root metafeed mfId
func (s metaFeedsService) GetOrCreateIndex(mfId, contentFeed refs.FeedRef, purpose, msgType string) (refs.FeedRef, error) {
	var empty refs.FeedRef

	// get the indexes feed, i.e. the feed listing indexes with a purpose "indexes"
	indexesFeedRef, err := s.getIndexesFeed(mfId)
	if err != nil {
		return empty, fmt.Errorf("failed to get `indexes` feed (%w)", err)
	}

	// look for any index, indexed by the `indexes` subfeed, that match the function signature's parameters
	potentialMatches, err := s.ListSubFeeds(indexesFeedRef)
	if err != nil {
		return empty, fmt.Errorf("failed to list subfeeds under `indexes` (%w)", err)
	}

	// query existing subfeeds to see if our desired subfeed already exists
	// (using contentFeed + msgType) before creating a new one
	for _, subfeed := range potentialMatches {
		msg, err := s.getMsgAtSeq(indexesFeedRef, subfeed.Seq)
		if err != nil {
			return empty, fmt.Errorf("GetOrCreateIndex had an error when iterating over potential subfeed matches (%w)", err)
		}

		// TODO (2021-09-20): loop back to go-metafeed & double check the implementation of GetMetadata (we are seemingly
		// getting empty strings, instead of false, for unregistered keys)
		// try to extract the query metadata
		querylang, _ := msg.GetMetadata("querylang")
		query, exists := msg.GetMetadata("query")
		if !exists || querylang != "ssb-ql-0" || query == "" {
			continue
		}

		// unpack the info from a string of json into something we can use
		var queryInfo ssb.MetadataQuery
		err = json.Unmarshal([]byte(query), &queryInfo)
		if err != nil {
			return empty, fmt.Errorf("GetOrCreateIndex had an error when unmarshaling query info (%w)", err)
		}

		// the index feed has already been created, return the matching subfeed
		if queryInfo.Author.Equal(contentFeed) && queryInfo.Type == msgType {
			return subfeed.Feed, nil
		}
	}

	// the subfeed didn't exist, let's create it
	metadata := map[string]string{
		"querylang": "ssb-ql-0",
		"author":    contentFeed.String(),
		"type":      msgType,
	}

	newFeed, err := s.CreateSubFeed(indexesFeedRef, purpose, refs.RefAlgoFeedSSB1, metadata)
	if err != nil {
		return refs.FeedRef{}, err
	}

	return newFeed, nil
}

func (s metaFeedsService) CreateSubFeed(mount refs.FeedRef, purpose string, format refs.RefAlgo, optionalMetadata ...map[string]string) (refs.FeedRef, error) {
	// TODO: validate format support (it's on the ebt multiformat branch)
	mountKeyPair, err := loadMetafeedKeyPairFromStore(s.keys, mount)
	if err != nil {
		return refs.FeedRef{}, err
	}

	// create nonce
	var nonce = make([]byte, 32)
	if _, err := rand.Read(nonce); err != nil {
		return refs.FeedRef{}, err
	}

	newSubfeedKeyPair, err := metakeys.DeriveFromSeed(mountKeyPair.Seed, string(nonce), format)
	if err != nil {
		return refs.FeedRef{}, err
	}

	newSubfeedAsTFK, err := tfk.Encode(newSubfeedKeyPair.Feed)
	if err != nil {
		return refs.FeedRef{}, err
	}

	// store the singing key
	err = storeKeyPair(s.keys, newSubfeedKeyPair)
	if err != nil {
		return refs.FeedRef{}, err
	}

	metaPublisher, err := message.OpenPublishLog(s.rxLog, s.users, mountKeyPair, message.SetHMACKey(s.hmacSecret))
	if err != nil {
		return refs.FeedRef{}, err
	}

	addContent := metamngmt.NewAddDerivedMessage(mountKeyPair.Feed, newSubfeedKeyPair.Feed, purpose, nonce)

	// we had some metadata :^)
	if len(optionalMetadata) > 0 {
		if len(optionalMetadata) > 1 {
			return refs.FeedRef{}, fmt.Errorf("CreateSubFeed: metadata to contain a single map, not multiple")
		}
		metadata := optionalMetadata[0]
		// note (2021-09-13): we're current only supporting ssb-ql-0 as a querylang
		if _, exists := metadata["querylang"]; !exists {
			return refs.FeedRef{}, fmt.Errorf("CreateSubFeed: expected metadata to have key `querylang`")
		} else if metadata["querylang"] != "ssb-ql-0" {
			return refs.FeedRef{}, fmt.Errorf("CreateSubFeed: expected metadata key `querylang` to have value `ssb-ql-0`, not `%s`", metadata["querylang"])
		}

		if _, exists := metadata["type"]; !exists {
			return refs.FeedRef{}, fmt.Errorf("CreateSubFeed: expected metadata to have key `type`")
		}
		if _, exists := metadata["author"]; !exists {
			return refs.FeedRef{}, fmt.Errorf("CreateSubFeed: expected metadata to have key `author`")
		}

		// convert author-as-string to author-as-refs.FeedRef
		author, err := refs.ParseFeedRef(metadata["author"])
		// create a `query` object with the expected ssb-ql-0 format
		if err != nil {
			return refs.FeedRef{}, fmt.Errorf("CreateSubFeed: failed to parse passed in author metadata (%w)", err)
		}
		queryJson, err := json.Marshal(ssb.MetadataQuery{Author: author, Type: metadata["type"]})
		if err != nil {
			return refs.FeedRef{}, err
		}

		err = addContent.InsertMetadata(map[string]string{
			"query": string(queryJson), "querylang": metadata["querylang"],
		})
		if err != nil {
			return refs.FeedRef{}, err
		}
	}

	addMsg, err := metafeed.SubSignContent(newSubfeedKeyPair.PrivateKey, addContent)
	if err != nil {
		return refs.FeedRef{}, err
	}

	msg, err := metaPublisher.Publish(addMsg)
	if err != nil {
		return refs.FeedRef{}, err
	}
	seqno := msg.Seq()

	// save the sequence number adding the subfeed to the metafeed. later, we can use the seqno to get the relevant
	// metadata, allowing us to know e.g. which index feeds have already been created or not
	encodedSeqno := make([]byte, binary.MaxVarintLen64)
	bytesWritten := binary.PutVarint(encodedSeqno, seqno)
	// trim the extra zeroes
	encodedSeqno = encodedSeqno[0:bytesWritten]

	listData, err := slp.Encode(newSubfeedAsTFK, encodedSeqno)
	if err != nil {
		return refs.FeedRef{}, err
	}

	// add the subfeed to the list of keys
	subfeedListID := keys.IDFromFeed(mountKeyPair.Feed)
	err = s.keys.AddKey(subfeedListID, keys.Recipient{
		Key:    keys.Key(listData),
		Scheme: keys.SchemeMetafeedSubkey,

		Metadata: keys.Metadata{
			ForFeed: &newSubfeedKeyPair.Feed,
		},
	})
	if err != nil {
		return refs.FeedRef{}, err
	}

	return newSubfeedKeyPair.Feed, nil
}

func (s metaFeedsService) TombstoneSubFeed(mount, subfeed refs.FeedRef) error {
	subfeedListing := keys.IDFromFeed(mount)
	feeds, err := s.keys.GetKeys(keys.SchemeMetafeedSubkey, subfeedListing)
	if err != nil {
		return fmt.Errorf("metafeed list: failed to get subfeed: %w", err)
	}

	var (
		found = false

		// the IDs as which the feed is stored as

		// once in the listing
		subfeedListID keys.Recipient

		// once as the signing key
		subfeedSignKeyID keys.ID
	)

	for i, f := range feeds {
		if f.Metadata.ForFeed.Equal(subfeed) {
			found = true

			tfkAndSeqno := slp.Decode(f.Key)

			if n := len(tfkAndSeqno); n != 2 {
				return fmt.Errorf("metafeed/list: invalid key element %d: have %d elements not 2", i, n)
			}

			subfeedListID = keys.Recipient{
				Key:    f.Key,
				Scheme: keys.SchemeMetafeedSubkey,
			}

			subfeedSignKeyID = tfkAndSeqno[0]

			break
		}
	}

	if !found {
		return ssb.ErrSubfeedNotActive
	}

	subfeedSigningKey, err := loadMetafeedKeyPairFromStore(s.keys, subfeed)
	if err != nil {
		return err
	}

	err = s.keys.RmKey(keys.SchemeMetafeedSubkey, subfeedListing, subfeedListID)
	if err != nil {
		return fmt.Errorf("failed to delete subfeed key from listing: %w", err)
	}
	err = s.keys.RmKeys(keys.SchemeFeedMessageSigningKey, subfeedSignKeyID)
	if err != nil {
		return fmt.Errorf("failed to delete subfeed signing key: %w", err)
	}

	mountKeyPair, err := loadMetafeedKeyPairFromStore(s.keys, mount)
	if err != nil {
		return err
	}

	metaPublisher, err := message.OpenPublishLog(s.rxLog, s.users, mountKeyPair, message.SetHMACKey(s.hmacSecret))
	if err != nil {
		return err
	}

	tombstoneContent := metamngmt.NewTombstoneMessage(subfeed, mountKeyPair.Feed)
	tombstoneMsg, err := metafeed.SubSignContent(subfeedSigningKey.PrivateKey, tombstoneContent)
	if err != nil {
		return err
	}

	_, err = metaPublisher.Publish(tombstoneMsg)
	if err != nil {
		return err
	}

	// deregister the indexfeed, preventing it from being used to publish new index messages
	_, err = s.indexManager.Deregister(subfeed)
	if err != nil {
		return fmt.Errorf("tombstone failure when deregistering index feed (%w)", err)
	}

	return nil
}

func (s metaFeedsService) ListSubFeeds(mount refs.FeedRef) ([]ssb.SubfeedListEntry, error) {
	subfeedListID := keys.IDFromFeed(mount)
	feeds, err := s.keys.GetKeys(keys.SchemeMetafeedSubkey, subfeedListID)
	if err != nil {
		if keys.IsNoSuchKey(err) {
			// this occurs when we try to list subfeeds for target metafeed which does not yet contain any subfeeds
			return []ssb.SubfeedListEntry{}, nil
		} else {
			return nil, fmt.Errorf("metafeed list: failed to get listing: %w", err)
		}
	}

	lst := make([]ssb.SubfeedListEntry, len(feeds))
	for i, feed := range feeds {
		tfkAndSeqno := slp.Decode(feed.Key)

		if n := len(tfkAndSeqno); n != 2 {
			return nil, fmt.Errorf("metafeed/list: invalid key element %d: have %d elements not 2", i, n)
		}

		var feedID tfk.Feed
		err = feedID.UnmarshalBinary(tfkAndSeqno[0])
		if err != nil {
			return nil, err
		}

		feedRef, err := feedID.Feed()
		if err != nil {
			return nil, err
		}

		decodedSeqno, bytesRead := binary.Varint(tfkAndSeqno[1])
		if decodedSeqno == 0 && bytesRead <= 0 {
			return []ssb.SubfeedListEntry{}, fmt.Errorf("ListSubFeeds: failed to varint decode sequence number from stored tfk")
		}

		lst[i] = ssb.SubfeedListEntry{
			Feed: feedRef,
			Seq:  decodedSeqno,
		}
	}

	return lst, nil
}

func (s metaFeedsService) getPublisher(as refs.FeedRef) (ssb.Publisher, error) {
	kp, err := loadMetafeedKeyPairFromStore(s.keys, as)
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to load signing keypair: %w", err)
	}

	publisher, err := message.OpenPublishLog(s.rxLog, s.users, kp, message.SetHMACKey(s.hmacSecret))
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to open publish log (%w)", err)
	}
	return publisher, nil
}

func (s metaFeedsService) Publish(as refs.FeedRef, content interface{}) (refs.Message, error) {
	mainPublisher, err := s.getPublisher(as)
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to get publisher (%w)", err)
	}
	msg, err := mainPublisher.Publish(content)
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to publish message (%w)", err)
	}

	indexFeedRef, indexMsg, err := s.indexManager.Process(msg)
	// there was no index feed related to this message or feed author
	var empty ssb.IndexedMessage
	if indexFeedRef.Equal(refs.FeedRef{}) && indexMsg == empty && err == nil {
		return msg, nil
	}
	// index processing had an error
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to index published message (%w)", err)
	}

	indexPublisher, err := s.getPublisher(indexFeedRef)
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to get index publisher (%w)", err)
	}
	_, err = indexPublisher.Publish(indexMsg)
	if err != nil {
		return nil, fmt.Errorf("metafeeds.Publish failed to publish index message (%w)", err)
	}

	return msg, nil
}

// utility functions
func loadMetafeedKeyPairFromStore(store *keys.Store, which refs.FeedRef) (metakeys.KeyPair, error) {
	feedAsTFK, err := tfk.Encode(which)
	if err != nil {
		return metakeys.KeyPair{}, err
	}
	dbSubkeyID := keys.ID(feedAsTFK)

	keys, err := store.GetKeys(keys.SchemeFeedMessageSigningKey, dbSubkeyID)
	if err != nil {
		return metakeys.KeyPair{}, err
	}
	if n := len(keys); n != 1 {
		return metakeys.KeyPair{}, fmt.Errorf("expected one signing key but got %d", n)
	}

	keyMaterial := slp.Decode(keys[0].Key)
	if n := len(keyMaterial); n != 2 {
		return metakeys.KeyPair{}, fmt.Errorf("expected two parts of key material but got %d", n)
	}

	return metakeys.KeyPair{
		Feed:       which,
		PrivateKey: ed25519.PrivateKey(keyMaterial[0]),
		Seed:       []byte(keyMaterial[1]),
	}, nil
}

// checkOrStoreKeypair only stores the keypair if it isn't stored yet
func checkOrStoreKeypair(store *keys.Store, kp metakeys.KeyPair) error {
	feedAsTFK, err := tfk.Encode(kp.Feed)
	if err != nil {
		return err
	}
	dbKeypairID := keys.ID(feedAsTFK)

	storedKeyPair, err := store.GetKeys(keys.SchemeFeedMessageSigningKey, dbKeypairID)
	if err == nil && len(storedKeyPair) == 1 {
		// keypair stored, store initalized
		return nil
	}

	// make sure we got error NoSuchKey
	var keystoreErr keys.Error
	if errors.As(err, &keystoreErr) {
		if keystoreErr.Code != keys.ErrorCodeNoSuchKey {
			return fmt.Errorf("checkAndStore: expected NoSuchKey error but got: %w", keystoreErr)
		}
		// ErrorCodeNoSuchKey as intended
	} else {
		return fmt.Errorf("checkAndStore: unexpected keystore failure: %w", err)
	}

	// now store the yet to be set keypair
	return storeKeyPair(store, kp)
}

func storeKeyPair(store *keys.Store, kp metakeys.KeyPair) error {
	feedAsTFK, err := tfk.Encode(kp.Feed)
	if err != nil {
		return err
	}
	dbKeypairID := keys.ID(feedAsTFK)

	keyMaterial, err := slp.Encode(kp.PrivateKey, kp.Seed)
	if err != nil {
		return err
	}

	err = store.AddKey(dbKeypairID, keys.Recipient{
		Key:    keyMaterial,
		Scheme: keys.SchemeFeedMessageSigningKey,
	})
	if err != nil {
		return err
	}

	return nil
}
