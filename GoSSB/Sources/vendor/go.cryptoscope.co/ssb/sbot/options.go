// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"encoding/base64"
	"fmt"
	"net"
	"os"
	"os/user"
	"path/filepath"
	"strings"
	"sync"

	"github.com/cryptix/go/logging"
	kitlog "github.com/go-kit/kit/log"
	"github.com/go-kit/kit/metrics"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/netwrap"
	"golang.org/x/sync/errgroup"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/graph"
	"go.cryptoscope.co/ssb/internal/netwraputil"
	"go.cryptoscope.co/ssb/message/multimsg"
	"go.cryptoscope.co/ssb/network"
	"go.cryptoscope.co/ssb/repo"
)

type MuxrpcEndpointWrapper func(muxrpc.Endpoint) muxrpc.Endpoint

type Sbot struct {
	info kitlog.Logger

	// TODO: this thing is way to big right now
	// because it's options and the resulting thing at once

	lateInit []Option

	rootCtx   context.Context
	Shutdown  context.CancelFunc
	closers   multiCloser
	idxDone   errgroup.Group
	idxInSync sync.WaitGroup

	closed   bool
	closedMu sync.Mutex
	closeErr error

	promisc  bool
	hopCount uint

	// TODO: these should all be options that are applied on the network construction...
	Network            ssb.Network
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

	repoPath string
	KeyPair  *ssb.KeyPair

	RootLog multimsg.AlterableLog

	PublishLog     ssb.Publisher
	signHMACsecret []byte

	mlogIndicies map[string]multilog.MultiLog
	simpleIndex  map[string]librarian.Index

	liveIndexUpdates bool
	indexStateMu     sync.Mutex
	indexStates      map[string]string

	GraphBuilder graph.Builder

	BlobStore   ssb.BlobStore
	WantManager ssb.WantManager

	// TODO: wrap better
	eventCounter metrics.Counter
	systemGauge  metrics.Gauge
	latency      metrics.Histogram

	ssb.Replicator
}

type Option func(*Sbot) error

func WithBlobStore(bs ssb.BlobStore) Option {
	return func(s *Sbot) error {
		s.BlobStore = bs
		return nil
	}
}

// DisableLiveIndexMode makes the update processing halt once it reaches the end of the rootLog
// makes it easier to rebuild indicies.
func DisableLiveIndexMode() Option {
	return func(s *Sbot) error {
		s.liveIndexUpdates = false
		return nil
	}
}

func WithRepoPath(path string) Option {
	return func(s *Sbot) error {
		s.repoPath = path
		return nil
	}
}

func DisableNetworkNode() Option {
	return func(s *Sbot) error {
		s.disableNetwork = true
		return nil
	}
}

func WithListenAddr(addr string) Option {
	return func(s *Sbot) error {
		var err error
		s.listenAddr, err = net.ResolveTCPAddr("tcp", addr)
		return errors.Wrap(err, "failed to parse tcp listen addr")
	}
}

func WithDialer(dial netwrap.Dialer) Option {
	return func(s *Sbot) error {
		s.dialer = dial
		return nil
	}
}

func WithNetworkConnTracker(ct ssb.ConnTracker) Option {
	return func(s *Sbot) error {
		s.networkConnTracker = ct
		return nil
	}
}

func WithUNIXSocket() Option {
	return func(s *Sbot) error {
		// this races because sbot might not be done with init yet
		// TODO: refactor network peer code and make unixsock implement that (those will be inited late anyway)
		if s.KeyPair == nil {
			return errors.Errorf("sbot/unixsock: keypair is nil. please use unixSocket with LateOption")
		}
		spoofWrapper := netwraputil.SpoofRemoteAddress(s.KeyPair.Id.ID)

		r := repo.New(s.repoPath)
		sockPath := r.GetPath("socket")

		// local clients (not using network package because we don't want conn limiting or advertising)
		c, err := net.Dial("unix", sockPath)
		if err == nil {
			c.Close()
			return errors.Errorf("sbot: repo already in use, socket accepted connection")
		}
		os.Remove(sockPath)
		os.MkdirAll(filepath.Dir(sockPath), 0700)

		uxLis, err := net.Listen("unix", sockPath)
		if err != nil {
			return err
		}
		s.closers.addCloser(uxLis)

		go func() {

			for {
				c, err := uxLis.Accept()
				if err != nil {
					if nerr, ok := err.(*net.OpError); ok {
						if nerr.Err.Error() == "use of closed network connection" {
							return
						}
					}

					err = errors.Wrap(err, "unix sock accept failed")
					s.info.Log("warn", err)
					logging.CheckFatal(err)
					continue
				}

				wc, err := spoofWrapper(c)
				if err != nil {
					c.Close()
					continue
				}
				go func(conn net.Conn) {
					defer conn.Close()

					pkr := muxrpc.NewPacker(conn)

					h, err := s.master.MakeHandler(conn)
					if err != nil {
						err = errors.Wrap(err, "unix sock make handler")
						s.info.Log("warn", err)
						logging.CheckFatal(err)
						return
					}

					edp := muxrpc.HandleWithLogger(pkr, h, s.info)

					ctx, cancel := context.WithCancel(s.rootCtx)
					srv := edp.(muxrpc.Server)
					if err := srv.Serve(ctx); err != nil {
						s.info.Log("conn", "serve exited", "err", err, "peer", conn.RemoteAddr())
					}
					edp.Terminate()
					cancel()
				}(wc)
			}
		}()
		return nil
	}
}

func WithAppKey(k []byte) Option {
	return func(s *Sbot) error {
		if n := len(k); n != 32 {
			return errors.Errorf("appKey: need 32 bytes got %d", n)
		}
		s.appKey = k
		return nil
	}
}

func WithNamedKeyPair(name string) Option {
	return func(s *Sbot) error {
		r := repo.New(s.repoPath)
		var err error
		s.KeyPair, err = repo.LoadKeyPair(r, name)
		return errors.Wrapf(err, "loading named key-pair %q failed", name)
	}
}

func WithJSONKeyPair(blob string) Option {
	return func(s *Sbot) error {
		var err error
		s.KeyPair, err = ssb.ParseKeyPair(strings.NewReader(blob))
		return errors.Wrap(err, "JSON KeyPair decode failed")
	}
}

func WithKeyPair(kp *ssb.KeyPair) Option {
	return func(s *Sbot) error {
		s.KeyPair = kp
		return nil
	}
}

func WithInfo(log kitlog.Logger) Option {
	return func(s *Sbot) error {
		s.info = log
		return nil
	}
}

func WithContext(ctx context.Context) Option {
	return func(s *Sbot) error {
		s.rootCtx = ctx
		return nil
	}
}

// TODO: remove all this network stuff and make them options on network
func WithPreSecureConnWrapper(cw netwrap.ConnWrapper) Option {
	return func(s *Sbot) error {
		s.preSecureWrappers = append(s.preSecureWrappers, cw)
		return nil
	}
}

// TODO: remove all this network stuff and make them options on network
func WithPostSecureConnWrapper(cw netwrap.ConnWrapper) Option {
	return func(s *Sbot) error {
		s.postSecureWrappers = append(s.postSecureWrappers, cw)
		return nil
	}
}

func WithEventMetrics(ctr metrics.Counter, lvls metrics.Gauge, lat metrics.Histogram) Option {
	return func(s *Sbot) error {
		s.eventCounter = ctr
		s.systemGauge = lvls
		s.latency = lat
		return nil
	}
}

func WithEndpointWrapper(mw MuxrpcEndpointWrapper) Option {
	return func(s *Sbot) error {
		s.edpWrapper = mw
		return nil
	}
}

// EnableAdvertismentBroadcasts controls local peer discovery through sending UDP broadcasts
func EnableAdvertismentBroadcasts(do bool) Option {
	return func(s *Sbot) error {
		s.enableAdverts = do
		return nil
	}
}

// EnableAdvertismentBroadcasts controls local peer discovery through listening for and connecting to UDP broadcasts
func EnableAdvertismentDialing(do bool) Option {
	return func(s *Sbot) error {
		s.enableDiscovery = do
		return nil
	}
}

func WithHMACSigning(key []byte) Option {
	return func(s *Sbot) error {
		if n := len(key); n != 32 {
			return errors.Errorf("WithHMACSigning: wrong key length (%d)", n)
		}
		s.signHMACsecret = key
		return nil
	}
}

// WithHops sets the number of friends (or bi-directionla follows) to walk between two peers
// controls fetch depth (whos feeds to fetch.
// 0: only my own follows
// 1: my friends follows
// 2: also their friends follows
// and how many hops a peer can be from self to for a connection to be accepted
func WithHops(h uint) Option {
	return func(s *Sbot) error {
		s.hopCount = h
		return nil
	}
}

// WithPromisc when enabled bypasses graph-distance lookups on connections and makes the gossip handler fetch the remotes feed
func WithPromisc(yes bool) Option {
	return func(s *Sbot) error {
		s.promisc = yes
		return nil
	}
}

// WithPublicAuthorizer configures who is considered "public" when accepting connections.
// By default, this is covered by the list of followed and blocked peers using the graph implementation.
func WithPublicAuthorizer(auth ssb.Authorizer) Option {
	return func(s *Sbot) error {
		if s.authorizer != nil {
			return fmt.Errorf("sbot: authorizer already configured")
		}
		s.authorizer = auth
		return nil
	}
}

// WithReplicator overwrites the default graph based decision maker, of which feeds to copy or block
func WithReplicator(r ssb.Replicator) Option {
	return func(s *Sbot) error {
		s.Replicator = r
		return nil
	}
}

// LateOption is a bit of a hack, it loads options after the _basic_ inititialisation is done (like repo location and keypair)
// this is mainly usefull for plugins that want to use a configured bot.
func LateOption(o Option) Option {
	return func(s *Sbot) error {
		s.lateInit = append(s.lateInit, o)
		return nil
	}
}

func New(fopts ...Option) (*Sbot, error) {
	var s Sbot
	s.liveIndexUpdates = true

	s.public = ssb.NewPluginManager()
	s.master = ssb.NewPluginManager()

	s.mlogIndicies = make(map[string]multilog.MultiLog)
	s.simpleIndex = make(map[string]librarian.Index)
	s.indexStates = make(map[string]string)

	for i, opt := range fopts {
		err := opt(&s)
		if err != nil {
			return nil, errors.Wrapf(err, "error applying option #%d", i)
		}
	}

	if s.repoPath == "" {
		u, err := user.Current()
		if err != nil {
			return nil, errors.Wrap(err, "error getting info on current user")
		}

		s.repoPath = filepath.Join(u.HomeDir, ".ssb-go")
	}

	if s.appKey == nil {
		ak, err := base64.StdEncoding.DecodeString("1KHLiKZvAvjbY1ziZEHMXawbCEIM6qwjCDm3VYRan/s=")
		if err != nil {
			return nil, errors.Wrap(err, "failed to decode default appkey")
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
		logger := kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stdout))
		logger = kitlog.With(logger, "ts", kitlog.DefaultTimestampUTC, "caller", kitlog.DefaultCaller)
		s.info = logger
	}

	if s.rootCtx == nil {
		s.rootCtx = context.TODO()
	}

	r := repo.New(s.repoPath)

	if s.KeyPair == nil {
		var err error
		s.KeyPair, err = repo.DefaultKeyPair(r)
		if err != nil {
			return nil, errors.Wrap(err, "sbot: failed to get keypair")
		}
	}

	return initSbot(&s)
}
