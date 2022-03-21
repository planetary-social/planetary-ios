// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/dgraph-io/badger/v3"
	"github.com/go-kit/kit/metrics"
	"github.com/rs/cors"
	"github.com/ssb-ngi-pointer/go-metafeed/metamngmt"
	"github.com/zeebo/bencode"
	librarian "go.cryptoscope.co/margaret/indexes"
	libbadger "go.cryptoscope.co/margaret/indexes/badger"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/margaret/multilog/roaring"
	multibadger "go.cryptoscope.co/margaret/multilog/roaring/badger"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/netwrap"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	"golang.org/x/sync/errgroup"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/indexes"
	"go.cryptoscope.co/ssb/internal/multicloser"
	"go.cryptoscope.co/ssb/internal/mutil"
	"go.cryptoscope.co/ssb/internal/statematrix"
	"go.cryptoscope.co/ssb/internal/storedrefs"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/message/multimsg"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/network"
	"go.cryptoscope.co/ssb/plugins/blobs"
	"go.cryptoscope.co/ssb/plugins/conn"
	"go.cryptoscope.co/ssb/plugins/ebt"
	"go.cryptoscope.co/ssb/plugins/friends"
	"go.cryptoscope.co/ssb/plugins/get"
	"go.cryptoscope.co/ssb/plugins/gossip"
	"go.cryptoscope.co/ssb/plugins/groups"
	"go.cryptoscope.co/ssb/plugins/legacyinvites"
	"go.cryptoscope.co/ssb/plugins/partial"
	privplug "go.cryptoscope.co/ssb/plugins/private"
	"go.cryptoscope.co/ssb/plugins/publish"
	"go.cryptoscope.co/ssb/plugins/rawread"
	"go.cryptoscope.co/ssb/plugins/replicate"
	"go.cryptoscope.co/ssb/plugins/status"
	"go.cryptoscope.co/ssb/plugins/tangles"
	"go.cryptoscope.co/ssb/plugins/whoami"
	"go.cryptoscope.co/ssb/plugins2/names"
	"go.cryptoscope.co/ssb/private"
	"go.cryptoscope.co/ssb/private/keys"
	"go.cryptoscope.co/ssb/repo"
	refs "go.mindeco.de/ssb-refs"
)

// Sbot is the database and replication server
type Sbot struct {
	info log.Logger

	// TODO: this thing is way to big right now
	// because it's options and the resulting thing in one

	// lateInit are options that need to be applied after others (like plugins that depend on keypairs)
	lateInit []Option

	rootCtx context.Context
	// Shutdown needs to be called to shutdown indexing
	Shutdown  context.CancelFunc
	closers   multicloser.MultiCloser
	idxDone   errgroup.Group
	idxInSync sync.WaitGroup

	closed   bool
	closedMu sync.Mutex
	closeErr error

	promisc  bool
	hopCount uint

	disableEBT                   bool
	disableLegacyLiveReplication bool

	Network *network.Node
	// TODO: these should all be options that are applied on the network construction...
	disableNetwork     bool
	appKey             []byte
	listenAddr         net.Addr
	dialer             netwrap.Dialer
	edpWrapper         MuxrpcEndpointWrapper
	networkConnTracker ssb.ConnTracker
	preSecureWrappers  []netwrap.ConnWrapper
	postSecureWrappers []netwrap.ConnWrapper

	public ssb.PluginManager
	master ssb.PluginManager

	authorizer ssb.Authorizer

	enableAdverts   bool
	enableDiscovery bool

	websocketAddr string

	repoPath string
	KeyPair  ssb.KeyPair

	Groups *private.Manager

	ReceiveLog multimsg.AlterableLog // the stream of messages as they arrived

	SeqResolver *repo.SequenceResolver

	PublishLog     ssb.Publisher
	signHMACsecret *[32]byte

	// hardcoded default indexes
	Users   *roaring.MultiLog // one sublog per feed
	Private *roaring.MultiLog // one sublog per keypair
	ByType  *roaring.MultiLog // one sublog per type: ... (special cases for private messages by suffix)
	Tangles *roaring.MultiLog // one sublog per root:%ref (actual root is in the get index)

	indexStore *badger.DB

	// plugin indexes
	mlogIndicies map[string]multilog.MultiLog
	simpleIndex  map[string]librarian.Index

	liveIndexUpdates bool
	indexStateMu     sync.Mutex
	indexStates      map[string]string

	ebtState *statematrix.StateMatrix

	verifyRouter *message.VerificationRouter

	GraphBuilder graph.Builder

	BlobStore   ssb.BlobStore
	WantManager ssb.WantManager

	// TODO: wrap better
	eventCounter metrics.Counter
	systemGauge  metrics.Gauge
	latency      metrics.Histogram

	enableMetafeeds bool
	MetaFeeds       ssb.MetaFeeds
	IndexFeeds      ssb.IndexFeedManager

	ssb.Replicator
}

// New creates an sbot instance using the passed options to configure it.
func New(fopts ...Option) (*Sbot, error) {
	var s = new(Sbot)
	s.liveIndexUpdates = true

	s.public = ssb.NewPluginManager()
	s.master = ssb.NewPluginManager()

	s.mlogIndicies = make(map[string]multilog.MultiLog)
	s.simpleIndex = make(map[string]librarian.Index)
	s.indexStates = make(map[string]string)

	s.disableLegacyLiveReplication = true

	for i, opt := range fopts {
		err := opt(s)
		if err != nil {
			return nil, fmt.Errorf("error applying option #%d: %w", i, err)
		}
	}

	if s.repoPath == "" {
		u, err := user.Current()
		if err != nil {
			return nil, fmt.Errorf("error getting info on current user: %w", err)
		}

		s.repoPath = filepath.Join(u.HomeDir, ".ssb-go")
	}

	if s.appKey == nil {
		ak, err := base64.StdEncoding.DecodeString("1KHLiKZvAvjbY1ziZEHMXawbCEIM6qwjCDm3VYRan/s=")
		if err != nil {
			return nil, fmt.Errorf("failed to decode default appkey: %w", err)
		}
		s.appKey = ak
	}

	if s.dialer == nil {
		s.dialer = netwrap.Dial
	}

	if s.listenAddr == nil {
		s.listenAddr = &net.TCPAddr{Port: network.DefaultPort}
	}

	if s.info == nil {
		logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
		logger = log.With(logger, "ts", log.DefaultTimestampUTC, "caller", log.DefaultCaller)
		s.info = logger
	}

	if s.rootCtx == nil {
		s.rootCtx, s.Shutdown = ShutdownContext(context.Background())
	}
	ctx := s.rootCtx

	storageRepo := repo.New(s.repoPath)

	var err error
	if s.KeyPair == nil {
		algo := refs.RefAlgoFeedSSB1
		if s.enableMetafeeds {
			algo = refs.RefAlgoFeedBendyButt
		}
		s.KeyPair, err = repo.DefaultKeyPair(storageRepo, algo)
		if err != nil {
			return nil, fmt.Errorf("sbot: failed to get keypair: %w", err)
		}
	}

	// TODO: optionize
	s.ReceiveLog, err = repo.OpenLog(storageRepo)
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to open rootlog: %w", err)
	}
	s.closers.AddCloser(s.ReceiveLog.(io.Closer))

	// if not configured
	if s.BlobStore == nil {
		// load default, local file blob store
		s.BlobStore, err = repo.OpenBlobStore(storageRepo)
		if err != nil {
			return nil, fmt.Errorf("sbot: failed to open blob store: %w", err)
		}
	}

	wantsLog := log.With(s.info, "module", "WantManager")
	wm := blobstore.NewWantManager(s.BlobStore,
		blobstore.WantWithLogger(wantsLog),
		blobstore.WantWithContext(s.rootCtx),
		blobstore.WantWithMetrics(s.systemGauge, s.eventCounter),
	)
	s.WantManager = wm
	s.closers.AddCloser(wm)

	for _, opt := range s.lateInit {
		err := opt(s)
		if err != nil {
			return nil, fmt.Errorf("sbot: failed to apply late option: %w", err)
		}
	}

	sm, err := statematrix.New(
		storageRepo.GetPath("ebt-state-matrix"),
		s.KeyPair.ID(),
	)
	if err != nil {
		return nil, err
	}
	s.closers.AddCloser(sm)
	s.ebtState = sm

	// open timestamp and sequence resovlers
	s.SeqResolver, err = repo.NewSequenceResolver(storageRepo)
	if err != nil {
		return nil, fmt.Errorf("error opening sequence resolver: %w", err)
	}
	idxTimestamps := indexes.NewTimestampSorter(s.SeqResolver)
	s.closers.AddCloser(idxTimestamps)
	s.serveIndex("timestamps", idxTimestamps)

	s.indexStore, err = repo.OpenBadgerDB(storageRepo.GetPath(repo.PrefixMultiLog, "shared-badger"))
	if err != nil {
		return nil, err
	}

	// default multilogs
	var mlogs = []struct {
		Name string
		Mlog **roaring.MultiLog
	}{
		{multilogs.IndexNameFeeds, &s.Users},
		{multilogs.IndexNamePrivates, &s.Private},
		{"msgTypes", &s.ByType},
		{"tangles", &s.Tangles},
		// TODO: channels
		// TODO: mentions
	}
	for _, index := range mlogs {
		mlog, err := multibadger.NewShared(s.indexStore, []byte("mlog-"+index.Name))
		if err != nil {
			return nil, err
		}
		s.closers.AddCloser(mlog)
		s.mlogIndicies[index.Name] = mlog

		*index.Mlog = mlog
	}

	// publish
	var pubopts = []message.PublishOption{
		message.UseNowTimestamps(true),
	}
	if s.signHMACsecret != nil {
		pubopts = append(pubopts, message.SetHMACKey(s.signHMACsecret))
	}
	s.PublishLog, err = message.OpenPublishLog(s.ReceiveLog, s.Users, s.KeyPair, pubopts...)
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to create publish log: %w", err)
	}

	// get(msgRef) -> rxLog sequence index
	getIdx, updateSink := indexes.OpenGet(s.indexStore)
	s.closers.AddCloser(updateSink)
	s.serveIndex("get", updateSink)
	s.simpleIndex["get"] = getIdx

	// groups2
	idxKeys := libbadger.NewIndexWithKeyPrefix(s.indexStore, keys.Recipients{}, []byte("group-and-signing"))
	keysStore := &keys.Store{
		Index: idxKeys,
	}
	s.closers.AddCloser(idxKeys)

	s.Groups = private.NewManager(s.KeyPair, s.PublishLog, keysStore, s.ReceiveLog, s, s.Tangles)

	groupsHelperMlog, err := multibadger.NewShared(s.indexStore, []byte("group-member-helper"))
	if err != nil {
		return nil, err
	}
	s.closers.AddCloser(groupsHelperMlog)

	// the big combined index of most the things
	combIdx, err := multilogs.NewCombinedIndex(
		s.repoPath,
		s.Groups,
		s.KeyPair.ID(),
		s.ReceiveLog,
		s.Users,
		s.Private,
		s.ByType,
		s.Tangles,
		groupsHelperMlog,
		sm,
	)
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to open combined application index: %w", err)
	}
	s.serveIndex("combined", combIdx)
	s.closers.AddCloser(combIdx)

	// groups re-indexing
	members, membersSnk := multilogs.NewMembershipIndex(
		log.With(s.info, "unit", "private-groups"),
		s.indexStore,
		s.KeyPair.ID(),
		s.Groups,
		combIdx,
	)
	s.closers.AddCloser(members)
	s.closers.AddCloser(membersSnk)

	addMemberIdxAddr := librarian.Addr("string:group/add-member")
	addMemberSeqs, err := groupsHelperMlog.Get(addMemberIdxAddr)
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to open sublog for add-member messages: %w", err)
	}
	justAddMemberMsgs := mutil.Indirect(s.ReceiveLog, addMemberSeqs)

	s.serveIndexFrom("group-members", membersSnk, justAddMemberMsgs)

	/* TODO: fix deadlock in index update locking
	if _, ok := s.simpleIndex["content-delete-requests"]; !ok {
		var dcrTrigger dropContentTrigger
		dcrTrigger.logger = log.With(s.info, "module", "dcrTrigger")
		dcrTrigger.root = s.ReceiveLog
		dcrTrigger.feeds = uf
		dcrTrigger.nuller = s
		err = MountSimpleIndex("content-delete-requests", dcrTrigger.MakeSimpleIndex)(s)
		if err != nil {
			return nil, errors.Wrap(err, "sbot: failed to open load default DCR index")
		}
	}
	*/

	// contact/follow graph
	gb := graph.NewBuilder(log.With(s.info, "module", "graph"), s.indexStore, s.signHMACsecret)
	seqSetter, updateContactsSink := gb.OpenContactsIndex()

	// create data source for contacts
	contactLog, err := s.ByType.Get(librarian.Addr("string:contact"))
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to open message contact sublog: %w", err)
	}
	justContacts := mutil.Indirect(s.ReceiveLog, contactLog)

	// fill the index
	s.serveIndexFrom("contacts", updateContactsSink, justContacts)
	s.closers.AddCloser(seqSetter)
	s.GraphBuilder = gb

	// abouts

	// create data source for abouts
	aboutSeqs, err := s.ByType.Get(librarian.Addr("string:about"))
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to open message about sublog: %w", err)
	}
	aboutsOnly := mutil.Indirect(s.ReceiveLog, aboutSeqs)

	var namesPlug names.Plugin
	_, aboutSnk := namesPlug.OpenSharedIndex(s.indexStore)
	s.closers.AddCloser(aboutSnk)
	s.serveIndexFrom("abouts", aboutSnk, aboutsOnly)

	// need to close s.indexStore _after_ the all the indexes closed and flushed
	s.closers.AddCloser(s.indexStore)

	// which feeds to replicate
	if s.Replicator == nil {
		s.Replicator, err = s.newGraphReplicator()
		if err != nil {
			return nil, err
		}
	}

	// load our network frontier
	ownFrontier, err := s.ebtState.Inspect(s.KeyPair.ID())
	if err != nil {
		return nil, err
	}

	// this peer has no ebt state yet
	if len(ownFrontier) == 0 {
		// use the replication lister and determine the stored feeds lenghts
		lister := s.Replicator.Lister().ReplicationList()

		feeds, err := lister.List()
		if err != nil {
			return nil, fmt.Errorf("ebt init state: failed to get userlist: %w", err)
		}

		for i, feed := range feeds {
			seq, err := s.CurrentSequence(feed)
			if err != nil {
				return nil, fmt.Errorf("failed to get sequence for entry %d: %w", i, err)
			}
			ownFrontier[feed.String()] = seq
		}

		// also update our own
		ownFrontier[s.KeyPair.ID().String()], err = s.CurrentSequence(s.KeyPair.ID())
		if err != nil {
			return nil, fmt.Errorf("failed to get our sequence: %w", err)
		}

		_, err = s.ebtState.Update(s.KeyPair.ID(), ownFrontier)
		if err != nil {
			return nil, err
		}
	}

	s.MetaFeeds = disabledMetaFeeds{}
	if s.enableMetafeeds {
		// a user might want to be able to read/replicate metafeeds without using bendybutt themselves
		if s.KeyPair.ID().Algo() == refs.RefAlgoFeedBendyButt {
			s.IndexFeeds, err = newIndexFeedManager(storageRepo.GetPath("indexfeeds"))
			if err != nil {
				return nil, fmt.Errorf("failed to initialize index feed manager: %w", err)
			}

			s.MetaFeeds, err = newMetaFeedService(s.ReceiveLog, s.IndexFeeds, s.Users, keysStore, s.KeyPair, s.signHMACsecret)
			if err != nil {
				return nil, fmt.Errorf("failed to initialize metafeed service: %w", err)
			}
		}

		// setup indexing

		// 1) all metafeed/* messages in bendybutt format
		justMetafeedMessages := repo.NewFilteredLog(s.ReceiveLog, func(msg refs.Message) bool {
			content := msg.ContentBytes()
			// the relevant messages will be in the form of [{content,...}, signature]
			var signedContent []bencode.RawMessage
			err := bencode.DecodeBytes(content, &signedContent)
			if err != nil {
				return false
			}

			if len(signedContent) < 2 { // not the expected form
				return false
			}

			var justTheType metamngmt.Typed
			// the 'type:xyz' we are looking for is in the object in the first element of the array
			err = bencode.DecodeBytes(signedContent[0], &justTheType)
			if err != nil {
				return false
			}
			rightType := strings.HasPrefix(justTheType.Type, "metafeed/")
			return rightType
		})

		_, mfSink := gb.OpenMetafeedsIndex()
		s.serveIndexFrom("metafeed", mfSink, justMetafeedMessages)

		// 2) metafeed/announce on normal format
		byTypeAnnouncementSeqs, err := s.ByType.Get(librarian.Addr("string:metafeed/announce"))
		if err != nil {
			return nil, fmt.Errorf("sbot: failed to open by type 'metafeed/announce' sublog: %w", err)
		}

		// convert sequences only to their actual messages using mutil.Indirect
		byTypeAnnouncements := mutil.Indirect(s.ReceiveLog, byTypeAnnouncementSeqs)

		_, announcementSink := gb.OpenAnnouncementIndex()
		s.serveIndexFrom("metafeed announcements", announcementSink, byTypeAnnouncements)
	}

	// from here on just network related stuff
	if s.disableNetwork {
		return s, nil
	}

	var inviteService *legacyinvites.Service

	// muxrpc handler creation and authoratization decider
	mkHandler := func(conn net.Conn) (muxrpc.Handler, error) {
		// bypassing badger-close bug to go through with an accept (or not) before closing the bot
		s.closedMu.Lock()
		defer s.closedMu.Unlock()

		remote, err := ssb.GetFeedRefFromAddr(conn.RemoteAddr())
		if err != nil {
			return nil, fmt.Errorf("sbot: expected an address containing an shs-bs addr: %w", err)
		}

		// TODO: we still can't see the feed format type from this

		if s.KeyPair.ID().PubKey().Equal(remote.PubKey()) {
			return s.master.MakeHandler(conn)
		}

		if inviteService != nil {
			err := inviteService.Authorize(remote)
			if err == nil {
				return inviteService.GuestHandler(), nil
			}
		}

		if s.promisc {
			return s.public.MakeHandler(conn)
		}

		auth := s.authorizer
		if auth == nil {
			auth = s.Replicator.Lister()
		}

		if s.latency != nil {
			start := time.Now()
			defer func() {
				s.latency.With("part", "graph_auth").Observe(time.Since(start).Seconds())
			}()
		}
		err = auth.Authorize(remote)
		if err == nil {
			return s.public.MakeHandler(conn)
		}

		// we also need to pass the other feed type up the stack...!
		// TODO: wrap conn with a new remoteAddr
		ggRemote, err := refs.NewFeedRefFromBytes(remote.PubKey(), refs.RefAlgoFeedGabby)
		err = auth.Authorize(ggRemote)
		if err == nil {
			level.Debug(s.info).Log("TODO", "found gg feed, using that. overhaul shs1 to support more payload in the handshake")
			return s.public.MakeHandler(conn)
		}

		// we also need to pass the other feed type up the stack...!
		// TODO: wrap conn with a new remoteAddr
		bbRemote, err := refs.NewFeedRefFromBytes(remote.PubKey(), refs.RefAlgoFeedBendyButt)
		err = auth.Authorize(bbRemote)
		if err == nil {
			level.Debug(s.info).Log("TODO", "found bendy-butt feed, using that. overhaul shs1 to support more payload in the handshake")
			return s.public.MakeHandler(conn)
		}

		// TOFU restore/resync
		if lst, err := s.Users.List(); err == nil && len(lst) == 0 {
			level.Warn(s.info).Log("event", "no stored feeds - attempting re-sync with trust-on-first-use")
			s.Replicate(s.KeyPair.ID())
			return s.public.MakeHandler(conn)
		}
		return nil, err
	}

	// publish
	authorLog, err := s.Users.Get(storedrefs.Feed(s.KeyPair.ID()))
	if err != nil {
		return nil, fmt.Errorf("failed to open user private index: %w", err)
	}
	s.master.Register(publish.NewPlug(log.With(s.info, "unit", "publish"), s.PublishLog, s.Groups, authorLog))

	// private
	// TODO: box2
	userPrivs, err := s.Private.Get(librarian.Addr("box1:") + storedrefs.Feed(s.KeyPair.ID()))
	if err != nil {
		return nil, fmt.Errorf("failed to open user private index: %w", err)
	}
	s.master.Register(privplug.NewPlug(
		log.With(s.info, "unit", "private"),
		s.KeyPair.ID(),
		s.Groups,
		s.PublishLog,
		private.NewUnboxerLog(s.ReceiveLog, userPrivs, s.KeyPair)))

	// whoami
	whoami := whoami.New(log.With(s.info, "unit", "whoami"), s.KeyPair.ID())
	s.public.Register(whoami)
	s.master.Register(whoami)

	// blobs
	blobs := blobs.New(log.With(s.info, "unit", "blobs"), s.KeyPair.ID(), s.BlobStore, wm)
	s.public.Register(blobs)
	s.master.Register(blobs) // TODO: does not need to open a createWants on this one?!

	// gossiping (legacy and ebt)
	fm := gossip.NewFeedManager(
		ctx,
		s.ReceiveLog,
		s.Users,
		log.With(s.info, "unit", "gossip"),
		s.systemGauge,
		s.eventCounter,
	)

	// outgoing gossip behavior
	var histOpts = []interface{}{
		gossip.Promisc(s.promisc),
	}

	if s.systemGauge != nil {
		histOpts = append(histOpts, s.systemGauge)
	}

	if s.eventCounter != nil {
		histOpts = append(histOpts, s.eventCounter)
	}

	if s.signHMACsecret != nil {
		histOpts = append(histOpts, gossip.HMACSecret(s.signHMACsecret))
	}

	s.verifyRouter, err = message.NewVerificationRouter(s.ReceiveLog, s.Users, s.signHMACsecret)
	if err != nil {
		return nil, err
	}

	if s.disableLegacyLiveReplication {
		histOpts = append(histOpts, gossip.WithLive(!s.disableLegacyLiveReplication))
	}

	gossipPlug := gossip.NewFetcher(ctx,
		log.With(s.info, "plugin", "gossip"),
		storageRepo,
		s.KeyPair.ID(),
		s.ReceiveLog, s.Users,
		fm, s.Replicator.Lister(),
		s.verifyRouter,
		histOpts...)

	if s.disableEBT {
		s.public.Register(gossipPlug)
	} else {
		ebtPlug := ebt.NewPlug(
			log.With(s.info, "plugin", "ebt"),
			s.KeyPair.ID(),
			s.ReceiveLog,
			s.Users,
			fm,
			sm,
			s.verifyRouter,
		)
		s.public.Register(ebtPlug)

		rn := negPlugin{replicateNegotiator{
			logger: log.With(s.info, "module", "replicate-negotiator"),

			lg:  gossipPlug.LegacyGossip,
			ebt: ebtPlug.MUXRPCHandler,
		}}
		s.public.Register(rn)
	}

	// incoming createHistoryStream handler
	hist := gossip.NewServer(ctx,
		log.With(s.info, "unit", "gossip/hist"),
		s.KeyPair.ID(),
		s.ReceiveLog, s.Users,
		s.Replicator.Lister(),
		fm,
		histOpts...)
	s.public.Register(hist)

	// get idx muxrpc handler
	s.master.Register(get.New(s, s.ReceiveLog, s.Groups))

	// about information
	s.master.Register(namesPlug)

	// (insecure) partial proof-of-concept for browser-core/demo
	plug := partial.New(s.info,
		fm,
		s.Users,
		s.ByType,
		s.Tangles,
		s.ReceiveLog, s)
	s.public.Register(plug)
	s.master.Register(plug)

	// group managment
	s.master.Register(groups.New(s.info, s.Groups))

	// raw log plugins

	sc := selfChecker{s.KeyPair.ID()}
	s.master.Register(rawread.NewByTypePlugin(
		s.info,
		s.ReceiveLog,
		s.ByType,
		s.Private,
		s.Groups,
		s.SeqResolver,
		sc))

	s.master.Register(rawread.NewRXLog(s.ReceiveLog)) // createLogStream
	s.master.Register(rawread.NewSortedStream(s.info, s.ReceiveLog, s.SeqResolver))
	s.master.Register(hist) // createHistoryStream

	s.master.Register(replicate.NewPlug(s.Users, s.KeyPair.ID(), s.Lister()))

	s.master.Register(friends.New(s.info, s.KeyPair.ID(), s.GraphBuilder))

	mh := namedPlugin{
		h:    manifestBlob,
		name: "manifest"}
	s.master.Register(mh)
	s.public.Register(mh)

	var tplug = tangles.NewPlugin(
		s.info,
		s,
		s.ReceiveLog,
		s.Tangles,
		s.Private,
		s.Groups,
		sc)
	s.master.Register(tplug)

	// tcp+shs
	opts := network.Options{
		Logger:              s.info,
		Dialer:              s.dialer,
		ListenAddr:          s.listenAddr,
		AdvertsSend:         s.enableAdverts,
		AdvertsConnectTo:    s.enableDiscovery,
		KeyPair:             s.KeyPair,
		AppKey:              s.appKey[:],
		MakeHandler:         mkHandler,
		ConnTracker:         s.networkConnTracker,
		BefreCryptoWrappers: s.preSecureWrappers,
		AfterSecureWrappers: s.postSecureWrappers,

		EventCounter:    s.eventCounter,
		SystemGauge:     s.systemGauge,
		EndpointWrapper: s.edpWrapper,
		Latency:         s.latency,

		WebsocketAddr: s.websocketAddr,
	}

	networkNode, err := network.New(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to create network node: %w", err)
	}
	blobsGetPathPrefix := "/blobs/get/"
	httpBlogsGet := func(w http.ResponseWriter, req *http.Request) {
		hlog := log.With(s.info, "http-handler", "blobs/get")
		rest := strings.TrimPrefix(req.URL.Path, blobsGetPathPrefix)
		blobRef, err := refs.ParseBlobRef(rest)
		if err != nil {
			level.Error(hlog).Log("err", err.Error())
			http.Error(w, "bad blob", http.StatusBadRequest)
			return
		}

		br, err := s.BlobStore.Get(blobRef)
		if err != nil {
			s.WantManager.Want(blobRef)
			level.Error(hlog).Log("err", err.Error())
			http.Error(w, "no such blob", http.StatusNotFound)
			return
		}

		// wh := w.Header()
		// sniff content-type?
		w.WriteHeader(http.StatusOK)
		_, err = io.Copy(w, br)
		if err != nil {
			level.Error(hlog).Log("err", err.Error())
		}
	}

	graphDumpPathPrefix := "/graph/dump"

	simpleRouter := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if strings.HasPrefix(req.URL.Path, blobsGetPathPrefix) {
			httpBlogsGet(w, req)
			return
		}

		if strings.HasPrefix(req.URL.Path, graphDumpPathPrefix) {
			s.GraphBuilder.(*graph.BadgerBuilder).DumpXMLOverHTTP(s.KeyPair.ID(), w, req)
			return
		}

		http.Error(w, "404", http.StatusNotFound)
	})
	networkNode.HandleHTTP(cors.Default().Handler(simpleRouter))

	inviteService, err = legacyinvites.New(
		log.With(s.info, "unit", "legacyInvites"),
		storageRepo,
		s.KeyPair.ID(),
		networkNode,
		s.PublishLog,
		s.ReceiveLog,
		s.Replicator,
		s.indexStore,
	)
	if err != nil {
		return nil, fmt.Errorf("sbot: failed to open legacy invites plugin: %w", err)
	}
	s.master.Register(inviteService.MasterPlugin())

	// TODO: should be gossip.connect but conflicts with our namespace assumption
	s.master.Register(conn.NewPlug(log.With(s.info, "unit", "conn"), networkNode, s))
	s.master.Register(status.New(s))

	s.public.Register(networkNode.TunnelPlugin())
	s.Network = networkNode

	return s, nil
}

// Close closes the bot by stopping network connections and closing the internal databases
func (s *Sbot) Close() error {
	s.closedMu.Lock()
	defer s.closedMu.Unlock()

	if s.closed {
		return s.closeErr
	}

	closeEvt := log.With(s.info, "event", "sbot closing")
	s.closed = true

	if s.Network != nil {
		if err := s.Network.Close(); err != nil {
			s.closeErr = fmt.Errorf("sbot: failed to close own network node: %w", err)
			return s.closeErr
		}
		s.Network.GetConnTracker().CloseAll()
		level.Debug(closeEvt).Log("msg", "connections closed")
	}

	if err := s.idxDone.Wait(); err != nil {
		s.closeErr = fmt.Errorf("sbot: index group shutdown failed: %w", err)
		return s.closeErr
	}
	level.Debug(closeEvt).Log("msg", "waited for indexes to close")

	if err := s.closers.Close(); err != nil {
		s.closeErr = err
		return s.closeErr
	}

	level.Info(closeEvt).Log("msg", "closers closed")
	return nil
}

type selfChecker struct {
	me refs.FeedRef
}

func (sc selfChecker) Authorize(remote refs.FeedRef) error {
	if sc.me.Equal(remote) {
		return nil
	}
	return fmt.Errorf("not authorized")
}
