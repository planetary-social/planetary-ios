package bindings

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"strings"
	"sync"
	"time"
	bindingslogging "verseproj/scuttlegobridge/logging"

	"github.com/boreq/errors"
	badgeroptions "github.com/dgraph-io/badger/v3/options"
	"github.com/planetary-social/scuttlego/service"
	"github.com/planetary-social/scuttlego/service/adapters/badger"
	"github.com/planetary-social/scuttlego/service/app"
	"github.com/planetary-social/scuttlego/service/app/commands"
	"github.com/planetary-social/scuttlego/service/app/queries"
	"github.com/planetary-social/scuttlego/service/di"
	"github.com/planetary-social/scuttlego/service/domain"
	"github.com/planetary-social/scuttlego/service/domain/feeds/formats"
	"github.com/planetary-social/scuttlego/service/domain/graph"
	"github.com/planetary-social/scuttlego/service/domain/identity"
	"github.com/planetary-social/scuttlego/service/domain/refs"
	"github.com/planetary-social/scuttlego/service/domain/transport/boxstream"
)

var ErrNodeIsNotRunning = errors.New("node isn't running")

const (
	kibibyte = 1024
	mebibyte = 1024 * kibibyte

	kilobyte = 1000
	megabyte = 1000 * kilobyte
)

type OnBlobDownloadedFn func(downloaded queries.BlobDownloaded) error
type MigrationOnRunningFn func(migrationIndex, migrationsCount int)
type MigrationOnErrorFn func(migrationIndex, migrationsCount, error int)
type MigrationOnDoneFn func(migrationsCount int)

type BotConfig struct {
	// NetworkKey is a base64 encoded network key.
	NetworkKey string `json:"networkKey"`

	// HMACKey is a base64 encoded message HMAC.
	HMACKey string `json:"hmacKey"`

	Hops       int    `json:"hops"`
	KeyBlob    string `json:"keyBlob"`
	Repo       string `json:"repo"`
	OldRepo    string `json:"oldRepo"`
	ListenAddr string `json:"listenAddr"`
	Testing    bool   `json:"testing"`
}

type Service struct {
	Ctx context.Context
	App app.Application
}

type Node struct {
	mutex sync.Mutex

	ctx        context.Context
	service    *service.Service
	cancel     context.CancelFunc
	cleanup    func()
	repository string
	wg         *sync.WaitGroup
}

func NewNode() *Node {
	return &Node{}
}

func (n *Node) Start(
	swiftConfig BotConfig,
	log bindingslogging.Logger,
	onBlobDownloaded OnBlobDownloadedFn,
	migrationOnRunningFn MigrationOnRunningFn,
	migrationOnErrorFn MigrationOnErrorFn,
	migrationOnDoneFn MigrationOnDoneFn,
) error {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if n.isRunning() {
		return errors.New("node is already running")
	}

	privateIdentity, err := n.toIdentity(swiftConfig)
	if err != nil {
		return errors.Wrap(err, "could not create the identity")
	}

	publicIdentityRef, err := refs.NewIdentityFromPublic(privateIdentity.Public())
	if err != nil {
		return errors.Wrap(err, "could not create the identity ref")
	}

	log.Debug().WithField("identity", publicIdentityRef).Message("building service")

	config, err := n.toConfig(swiftConfig, log)
	if err != nil {
		return errors.Wrap(err, "could not convert the config")
	}

	if err = os.MkdirAll(config.DataDirectory, 0700); err != nil {
		return errors.Wrap(err, "could not create the data directory")
	}

	ctx, cancel := context.WithCancel(context.Background())

	service, cleanup, err := di.BuildService(privateIdentity, config)
	if err != nil {
		cancel()
		return errors.Wrap(err, "error building service")
	}

	if err := n.runMigrations(ctx, service, migrationOnRunningFn, migrationOnErrorFn, migrationOnDoneFn); err != nil {
		cancel()
		cleanup()
		return errors.Wrap(err, "error running migrations")
	}

	n.ctx = ctx
	n.service = &service
	n.cancel = cancel
	n.cleanup = cleanup
	n.repository = config.DataDirectory
	n.wg = &sync.WaitGroup{}

	go n.printStats(ctx, log, service)

	n.wg.Add(1)
	go func() {
		defer n.wg.Done()

		for event := range service.App.Queries.BlobDownloadedEvents.Handle(ctx) {
			logger := log.WithField("blob", event.Id).WithField("size", event.Size.InBytes())
			if err := onBlobDownloaded(event); err != nil {
				logger.Error().WithField(bindingslogging.ErrorField, err).Message("error calling onBlobDownloaded")
			} else {
				logger.Debug().Message("called onBlobDownloaded")
			}
		}
	}()

	n.wg.Add(1)
	go func() {
		defer n.wg.Done()

		if err := service.Run(ctx); err != nil {
			if !errors.Is(err, context.Canceled) {
				log.Error().WithField(bindingslogging.ErrorField, err).Message("service terminated with an error")
			}
			// todo what to do if the service terminates for some reason? should it be restarted or should we just cleanup node?
		}
	}()

	return nil
}

func (n *Node) Stop() error {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if !n.isRunning() {
		return ErrNodeIsNotRunning
	}

	n.cancel()
	n.cleanup()

	n.wg.Wait()

	n.ctx = nil
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

func (n *Node) Get() (*Service, error) {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	if !n.isRunning() {
		return nil, errors.New("node isn't running")
	}

	return &Service{
		Ctx: n.ctx,
		App: n.service.App,
	}, nil
}

func (n *Node) IsRunning() bool {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	return n.isRunning()
}

func (n *Node) isRunning() bool {
	return n.service != nil
}

func (n *Node) runMigrations(
	ctx context.Context,
	service service.Service,
	migrationOnRunningFn MigrationOnRunningFn,
	migrationOnErrorFn MigrationOnErrorFn,
	migrationOnDoneFn MigrationOnDoneFn,
) error {
	progressCallback, err := NewProgressCallback(migrationOnRunningFn, migrationOnErrorFn, migrationOnDoneFn)
	if err != nil {
		return errors.Wrap(err, "error creating the progress callback")
	}

	migrationsCmd, err := commands.NewRunMigrations(progressCallback)
	if err != nil {
		return errors.Wrap(err, "error creating the migration command")
	}

	if err := service.App.Commands.RunMigrations.Run(ctx, migrationsCmd); err != nil {
		return errors.Wrap(err, "error running migrations")
	}

	return nil
}

func (n *Node) toConfig(swiftConfig BotConfig, bindingsLogger bindingslogging.Logger) (service.Config, error) {
	networkKeyBytes, err := base64.StdEncoding.DecodeString(swiftConfig.NetworkKey)
	if err != nil {
		return service.Config{}, errors.Wrap(err, "failed to decode network key")
	}

	networkKey, err := boxstream.NewNetworkKey(networkKeyBytes)
	if err != nil {
		return service.Config{}, errors.Wrap(err, "failed to create network key")
	}

	messageHMACBytes, err := base64.StdEncoding.DecodeString(swiftConfig.HMACKey)
	if err != nil {
		return service.Config{}, errors.Wrap(err, "failed to decode message hmac")
	}

	messageHMAC, err := formats.NewMessageHMAC(messageHMACBytes)
	if err != nil {
		return service.Config{}, errors.Wrap(err, "failed to create message hmac")
	}

	hops, err := graph.NewHops(swiftConfig.Hops)
	if err != nil {
		return service.Config{}, errors.Wrap(err, "error creating hops")
	}

	config := service.Config{
		DataDirectory:      swiftConfig.Repo,
		GoSSBDataDirectory: swiftConfig.OldRepo,
		ListenAddress:      swiftConfig.ListenAddr,
		NetworkKey:         networkKey,
		MessageHMAC:        messageHMAC,
		LoggingSystem:      bindingsLogger,
		PeerManagerConfig: domain.PeerManagerConfig{
			PreferredPubs: nil,
		},
		Hops: &hops,
		ModifyBadgerOptions: func(options service.BadgerOptions) {
			options.SetNumGoroutines(2)
			options.SetNumCompactors(2)
			options.SetCompression(badgeroptions.ZSTD)
			options.SetLogger(badger.NewLogger(bindingsLogger, badger.LoggerLevelInfo))
			options.SetValueLogFileSize(32 * mebibyte)
			options.SetBlockCacheSize(32 * mebibyte)
			options.SetIndexCacheSize(0)
			options.SetSyncWrites(true)
		},
	}

	config.SetDefaults()

	return config, nil
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

func (n *Node) printStats(ctx context.Context, logger bindingslogging.Logger, service service.Service) {
	var startTimestamp time.Time
	var startMessages int

	for {
		stats, err := service.App.Queries.Status.Handle()
		if err != nil {
			logger.
				Error().
				WithField(bindingslogging.ErrorField, err).
				Message("error executing status query")
		} else {
			var peers []string
			for _, remote := range stats.Peers {
				peers = append(peers, remote.Identity.String())
			}

			logger := logger.
				Debug().
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
			logger = logger.WithField("mallocs", m.Mallocs)
			logger = logger.WithField("frees", m.Frees)
			logger = logger.WithField("gc_cpu_fraction", m.GCCPUFraction)
			logger = logger.WithField("num_gc", m.NumGC)

			logger.Message("stats")
		}

		select {
		case <-time.After(30 * time.Second):
		case <-ctx.Done():
			return
		}
	}
}

func bToMb(b uint64) uint64 {
	return b / megabyte
}

type identityBlob struct {
	Private string `json:"private"`
}
