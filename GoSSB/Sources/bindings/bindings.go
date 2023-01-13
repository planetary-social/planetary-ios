package bindings

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/boreq/errors"
	badgeroptions "github.com/dgraph-io/badger/v3/options"
	kitlog "github.com/go-kit/kit/log"
	"github.com/planetary-social/scuttlego/di"
	"github.com/planetary-social/scuttlego/logging"
	"github.com/planetary-social/scuttlego/service/adapters/badger"
	"github.com/planetary-social/scuttlego/service/app/queries"
	"github.com/planetary-social/scuttlego/service/domain"
	"github.com/planetary-social/scuttlego/service/domain/feeds/formats"
	"github.com/planetary-social/scuttlego/service/domain/identity"
	"github.com/planetary-social/scuttlego/service/domain/transport/boxstream"
	refs "go.mindeco.de/ssb-refs"
	"os"
	"path"
	"runtime"
	"runtime/pprof"
	"strings"
	"sync"
	"time"
)

const (
	kibibyte = 1024
	mebibyte = 1024 * kibibyte
)

type OnBlobDownloadedFn func(downloaded queries.BlobDownloaded) error

type BotConfig struct {
	AppKey     string `json:"AppKey"`
	HMACKey    string `json:"HMACKey"`
	KeyBlob    string `json:"KeyBlob"`
	Repo       string `json:"Repo"`
	OldRepo    string `json:"OldRepo"`
	ListenAddr string `json:"ListenAddr"`
	Hops       uint   `json:"Hops"`
	Testing    bool   `json:"Testing"`

	// Pubs that host planetary specific muxrpc calls
	ServicePubs []refs.FeedRef `json:"ServicePubs"`

	ViewDBSchemaVersion uint `json:"SchemaVersion"` // ViewDatabase number for filename
}

type Node struct {
	mutex      sync.Mutex
	service    *di.Service
	cancel     context.CancelFunc
	cleanup    func()
	repository string
	wg         *sync.WaitGroup
}

func NewNode() *Node {
	return &Node{}
}

func (n *Node) Start(swiftConfig BotConfig, log kitlog.Logger, onBlobDownloaded OnBlobDownloadedFn) error {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if n.isRunning() {
		return errors.New("node is already running")
	}

	local, err := n.toIdentity(swiftConfig)
	if err != nil {
		return errors.Wrap(err, "could not create the identity")
	}

	config, err := n.toConfig(swiftConfig, log)
	if err != nil {
		return errors.Wrap(err, "could not convert the config")
	}

	if err = os.MkdirAll(config.DataDirectory, 0700); err != nil {
		return errors.Wrap(err, "could not create the data directory") // todo should this be here?
	}

	ctx, cancel := context.WithCancel(context.Background())

	service, cleanup, err := di.BuildService(ctx, local, config)
	if err != nil {
		cancel()
		return errors.Wrap(err, "error building service")
	}

	n.service = &service
	n.cancel = cancel
	n.cleanup = cleanup
	n.repository = config.DataDirectory
	n.wg = &sync.WaitGroup{}

	go n.printStats(ctx, config.Logger, service)
	//go n.captureProfileCPU(ctx, config)
	//go n.captureProfileMemory(ctx, config)

	n.wg.Add(1)
	go func() {
		defer n.wg.Done()

		for event := range service.App.Queries.BlobDownloadedEvents.Handle(ctx) {
			logger := config.Logger.WithField("blob", event.Id).WithField("size", event.Size.InBytes())
			if err := onBlobDownloaded(event); err != nil {
				logger.WithError(err).Error("error calling onBlobDownloaded")
			} else {
				logger.Debug("called onBlobDownloaded")
			}
		}
	}()

	n.wg.Add(1)
	go func() {
		defer n.wg.Done()

		if err := service.Run(ctx); err != nil {
			fmt.Println("service has terminated with an error", err)
			// todo what to do if the service terminates for some reason? should it be restarted or should we just cleanup node?
		}
	}()

	return nil
}

func (n *Node) Stop() error {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if !n.isRunning() {
		return errors.New("node isn't running")
	}

	n.cancel()
	n.cleanup()

	n.wg.Wait()

	n.service = nil
	n.cancel = nil
	n.repository = ""
	n.cleanup = nil
	n.wg = nil

	return nil
}

func (n *Node) Repository() (string, error) {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if !n.isRunning() {
		return "", errors.New("node isn't running")
	}

	return n.repository, nil
}

func (n *Node) Get() (*di.Service, error) {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if !n.isRunning() {
		return nil, errors.New("node isn't running")
	}

	return n.service, nil
}

func (n *Node) IsRunning() bool {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	return n.isRunning()
}

func (n *Node) isRunning() bool {
	return n.service != nil
}

func (n *Node) toConfig(swiftConfig BotConfig, kitlogLogger kitlog.Logger) (di.Config, error) {
	networkKeyBytes, err := base64.StdEncoding.DecodeString(swiftConfig.AppKey)
	if err != nil {
		return di.Config{}, errors.Wrap(err, "failed to decode network key")
	}

	networkKey, err := boxstream.NewNetworkKey(networkKeyBytes)
	if err != nil {
		return di.Config{}, errors.Wrap(err, "failed to create network key")
	}

	messageHMACBytes, err := base64.StdEncoding.DecodeString(swiftConfig.HMACKey)
	if err != nil {
		return di.Config{}, errors.Wrap(err, "failed to decode message hmac")
	}

	messageHMAC, err := formats.NewMessageHMAC(messageHMACBytes)
	if err != nil {
		return di.Config{}, errors.Wrap(err, "failed to create message hmac")
	}

	// todo do something with hops
	// todo do something service pubs?
	// todo use the testing option to change log level?

	logger := n.newLogger(kitlogLogger)

	config := di.Config{
		DataDirectory:      swiftConfig.Repo,
		GoSSBDataDirectory: swiftConfig.OldRepo,
		ListenAddress:      swiftConfig.ListenAddr,
		NetworkKey:         networkKey,
		MessageHMAC:        messageHMAC,
		Logger:             logger,
		PeerManagerConfig: domain.PeerManagerConfig{
			PreferredPubs: nil,
		},
		ModifyBadgerOptions: func(options di.BadgerOptions) {
			options.SetNumGoroutines(2)
			options.SetNumCompactors(2)
			options.SetCompression(badgeroptions.ZSTD)
			options.SetLogger(badger.NewLogger(logger.New("badger"), badger.LoggerLevelInfo))
			options.SetValueLogFileSize(32 * mebibyte)
			options.SetBlockCacheSize(32 * mebibyte)
			options.SetIndexCacheSize(0)
		},
	}

	config.SetDefaults() // todo this should be automatic

	return config, nil
}

func (n *Node) newLogger(kitlogLogger kitlog.Logger) KitlogLogger {
	return NewKitlogLogger(kitlogLogger, "gossb", logging.LevelDebug)
}

func (n *Node) toIdentity(config BotConfig) (identity.Private, error) {
	var blob identityBlob
	err := json.Unmarshal([]byte(config.KeyBlob), &blob)
	if err != nil {
		return identity.Private{}, errors.Wrap(err, "failed to unmarshal identity blob")
	}

	base64String := strings.TrimSuffix(blob.Private, ".ed25519")

	privateKeyBytes, err := base64.StdEncoding.DecodeString(base64String)
	if err != nil {
		return identity.Private{}, errors.Wrap(err, "failed to decode network key")
	}

	return identity.NewPrivateFromBytes(privateKeyBytes)
}

func (n *Node) printStats(ctx context.Context, logger logging.Logger, service di.Service) {
	var startTimestamp time.Time
	var startMessages int

	for {
		stats, err := service.App.Queries.Status.Handle()
		if err != nil {
			logger.
				WithError(err).
				Error("stats error")
		} else {
			var peers []string
			for _, remote := range stats.Peers {
				peers = append(peers, remote.Identity.String())
			}

			logger := logger.
				WithField("messages", stats.NumberOfMessages).
				WithField("feeds", stats.NumberOfFeeds).
				WithField("peers", strings.Join(peers, ", ")).
				WithField("goroutines", runtime.NumGoroutine())

			if startTimestamp.IsZero() {
				startTimestamp = time.Now()
				startMessages = stats.NumberOfMessages
			} else {
				speed := float64(stats.NumberOfMessages-startMessages) / time.Since(startTimestamp).Minutes()
				logger = logger.WithField("speed", fmt.Sprintf("%f msgs/min", speed))
			}

			var m runtime.MemStats
			runtime.ReadMemStats(&m)

			logger = logger.WithField("mem_alloc", fmt.Sprintf("%v MB", bToMb(m.Alloc)))
			logger = logger.WithField("mem_sys", fmt.Sprintf("%v MB", bToMb(m.Sys)))
			logger = logger.WithField("num_gc", m.NumGC)

			logger.Debug("stats")
		}

		select {
		case <-time.After(30 * time.Second):
		case <-ctx.Done():
			return
		}
	}
}

func (n *Node) captureProfileCPU(ctx context.Context, config di.Config) {
	for {
		name := path.Join(config.DataDirectory, fmt.Sprintf("%d.cpuprofile", time.Now().Unix()))
		f, err := os.Create(name)
		if err != nil {
			panic(err)
		}

		err = pprof.StartCPUProfile(f)
		if err != nil {
			panic(err)
		}

		cleanup := func() {
			pprof.StopCPUProfile()

			if err := f.Close(); err != nil {
				panic(err)
			}
		}

		select {
		case <-time.After(30 * time.Second):
		case <-ctx.Done():
			cleanup()
			return
		}

		cleanup()
	}
}

func (n *Node) captureProfileMemory(ctx context.Context, config di.Config) {
	for {
		name := path.Join(config.DataDirectory, fmt.Sprintf("%d.heapprofile", time.Now().Unix()))
		f, err := os.Create(name)
		if err != nil {
			panic(err)
		}

		err = pprof.WriteHeapProfile(f)
		if err != nil {
			panic(err)
		}

		if err := f.Close(); err != nil {
			panic(err)
		}

		select {
		case <-time.After(30 * time.Second):
		case <-ctx.Done():
			return
		}
	}
}

func bToMb(b uint64) uint64 {
	return b / 1000 / 1000
}

type identityBlob struct {
	Private string `json:"private"`
}
