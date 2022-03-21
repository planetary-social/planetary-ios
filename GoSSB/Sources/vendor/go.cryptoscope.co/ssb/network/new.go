// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package network

import (
	"context"
	"crypto/ed25519"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"

	"github.com/go-kit/kit/metrics"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/neterr"
	refs "go.mindeco.de/ssb-refs"
)

// DefaultPort is the default listening port for ScuttleButt.
const DefaultPort = 8008

type Options struct {
	Logger log.Logger

	Dialer     netwrap.Dialer
	ListenAddr net.Addr

	AdvertsSend      bool
	AdvertsConnectTo bool

	KeyPair     ssb.KeyPair
	AppKey      []byte
	MakeHandler func(net.Conn) (muxrpc.Handler, error)

	ConnTracker ssb.ConnTracker

	// PreSecureWrappers are applied before the shs+boxstream wrapping takes place
	// usefull for accessing the sycall.Conn to apply control options on the socket
	BefreCryptoWrappers []netwrap.ConnWrapper

	// AfterSecureWrappers are applied afterwards, usefull to debug muxrpc content
	AfterSecureWrappers []netwrap.ConnWrapper

	EventCounter    metrics.Counter
	SystemGauge     metrics.Gauge
	Latency         metrics.Histogram
	EndpointWrapper func(muxrpc.Endpoint) muxrpc.Endpoint

	WebsocketAddr string
}

type Node struct {
	opts Options

	log log.Logger

	listening chan struct{}

	listenerLock sync.Mutex
	lisClose     sync.Once
	lis          net.Listener

	dialer        netwrap.Dialer
	localDiscovRx *Discoverer
	localDiscovTx *Advertiser
	secretServer  *secretstream.Server
	secretClient  *secretstream.Client
	connTracker   ssb.ConnTracker

	beforeCryptoConnWrappers []netwrap.ConnWrapper
	afterSecureConnWrappers  []netwrap.ConnWrapper

	remotesLock sync.Mutex
	remotes     map[string]muxrpc.Endpoint

	edpWrapper func(muxrpc.Endpoint) muxrpc.Endpoint
	evtCtr     metrics.Counter
	sysGauge   metrics.Gauge
	latency    metrics.Histogram

	// "ssb-ws"
	httpLis     net.Listener
	httpHandler http.Handler
}

func New(opts Options) (*Node, error) {
	n := &Node{
		opts:    opts,
		remotes: make(map[string]muxrpc.Endpoint),
	}

	if opts.ConnTracker == nil {
		opts.ConnTracker = NewLastWinsTracker()
	}
	n.connTracker = opts.ConnTracker

	var err error

	if opts.Dialer != nil {
		n.dialer = opts.Dialer
	} else {
		n.dialer = netwrap.Dial
	}

	connKeyPair := ssb.EdKeyPair(opts.KeyPair)

	n.secretClient, err = secretstream.NewClient(connKeyPair, opts.AppKey)
	if err != nil {
		return nil, fmt.Errorf("error creating secretstream.Client: %w", err)
	}

	n.secretServer, err = secretstream.NewServer(connKeyPair, opts.AppKey)
	if err != nil {
		return nil, fmt.Errorf("error creating secretstream.Server: %w", err)
	}

	if n.opts.AdvertsSend {
		n.localDiscovTx, err = NewAdvertiser(n.opts.ListenAddr, opts.KeyPair)
		if err != nil {
			return nil, fmt.Errorf("error creating Advertiser: %w", err)
		}
	}

	if n.opts.AdvertsConnectTo {
		n.localDiscovRx, err = NewDiscoverer(opts.KeyPair)
		if err != nil {
			return nil, fmt.Errorf("error creating Advertiser: %w", err)
		}
	}

	n.beforeCryptoConnWrappers = opts.BefreCryptoWrappers
	n.afterSecureConnWrappers = opts.AfterSecureWrappers

	n.listening = make(chan struct{})

	n.edpWrapper = opts.EndpointWrapper
	n.evtCtr = opts.EventCounter
	n.sysGauge = opts.SystemGauge
	n.latency = opts.Latency

	if n.sysGauge != nil {
		n.sysGauge.With("part", "conns").Set(0)
		n.sysGauge.With("part", "fetches").Set(0)

		n.connTracker = NewInstrumentedConnTracker(n.connTracker, n.sysGauge, n.latency)
	}
	n.log = opts.Logger

	// local websocket
	wsHandler := websockHandler(n)
	httpHandler := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		url := req.URL.String()
		if url == "/" {
			wsHandler(w, req)
			return
		}
		// n.log.Log("http-url-req", url)
		if n.httpHandler != nil {
			n.httpHandler.ServeHTTP(w, req)
		}
	})

	if addr := opts.WebsocketAddr; addr != "" {
		n.httpLis, err = net.Listen("tcp", addr)
		if err != nil {
			return nil, err
		}

		// TODO: move to serve
		go func() {
			err := http.Serve(n.httpLis, httpHandler)
			level.Error(n.log).Log("conn", "ssb-ws :8998 listen exited", "err", err)
		}()
	}

	return n, nil
}

func (n *Node) HandleHTTP(h http.Handler) {
	n.httpHandler = h
}

func (n *Node) GetConnTracker() ssb.ConnTracker {
	return n.connTracker
}

// GetEndpointFor returns a muxrpc endpoint to call the remote identified by the passed feed ref
// retruns false if there is no such connection
// TODO: merge with conntracker
func (n *Node) GetEndpointFor(ref refs.FeedRef) (muxrpc.Endpoint, bool) {
	n.remotesLock.Lock()
	defer n.remotesLock.Unlock()

	edp, has := n.remotes[ref.String()]
	return edp, has
}

// TODO: merge with conntracker
func (n *Node) GetAllEndpoints() []ssb.EndpointStat {
	n.remotesLock.Lock()
	defer n.remotesLock.Unlock()

	var stats []ssb.EndpointStat

	for ref, edp := range n.remotes {
		id, _ := refs.ParseFeedRef(ref)
		remote := edp.Remote()
		ok, durr := n.connTracker.Active(remote)
		if !ok {
			continue
		}
		stats = append(stats, ssb.EndpointStat{
			ID:       id,
			Addr:     remote,
			Since:    durr,
			Endpoint: edp,
		})
	}
	return stats
}

// TODO: merge with conntracker
func (n *Node) addRemote(edp muxrpc.Endpoint) {
	n.remotesLock.Lock()
	defer n.remotesLock.Unlock()
	r, err := ssb.GetFeedRefFromAddr(edp.Remote())
	if err != nil {
		panic(err)
	}
	// ref := r.Ref()
	// if oldEdp, has := n.remotes[ref]; has {
	// n.log.Log("remotes", "previous active", "ref", ref)
	// c := client.FromEndpoint(oldEdp)
	// _, err := c.Whoami()
	// if err == nil {
	// 	// old one still works
	// 	return
	// }
	// }
	// replace with new
	n.remotes[r.String()] = edp
}

// TODO: merge with conntracker
func (n *Node) removeRemote(edp muxrpc.Endpoint) {
	n.remotesLock.Lock()
	defer n.remotesLock.Unlock()
	r, err := ssb.GetFeedRefFromAddr(edp.Remote())
	if err != nil {
		panic(err)
	}
	delete(n.remotes, r.String())
}

func (n *Node) handleConnection(ctx context.Context, origConn net.Conn, isServer bool, hws ...muxrpc.HandlerWrapper) {
	// TODO: overhaul events and logging levels
	conn, err := n.applyConnWrappers(origConn)
	if err != nil {
		origConn.Close()
		level.Error(n.log).Log("msg", "node/Serve: failed to wrap connection", "err", err)
		return
	}

	// TODO: obfuscate the remote address by nulling bytes in it before printing ip and pubkey in full
	remoteRef, err := ssb.GetFeedRefFromAddr(conn.RemoteAddr())
	if err != nil {
		conn.Close()
		level.Error(n.log).Log("conn", "not shs authorized", "err", err)
		return
	}
	rLogger := log.With(n.log, "peer", remoteRef.ShortSigil())

	ok, ctx := n.connTracker.OnAccept(ctx, conn)
	if !ok {
		err := conn.Close()
		level.Debug(rLogger).Log("conn", "ignored", "err", err)
		return
	}

	defer func() {
		n.connTracker.OnClose(conn)
		conn.Close()
		origConn.Close()
	}()

	if n.evtCtr != nil {
		n.evtCtr.With("event", "connection").Add(1)
	}

	h, err := n.opts.MakeHandler(conn)
	if err != nil {
		var eOOR ssb.ErrOutOfReach
		if errors.As(err, &eOOR) {
			return // ignore silently
		}
		level.Debug(rLogger).Log("conn", "mkHandler", "err", err)
		return
	}

	for _, hw := range hws {
		h = hw(h)
	}

	// connLogger := n.log
	// connLogger = level.NewFilter(connLogger, level.AllowInfo())
	connLogger := log.NewNopLogger()

	edp := muxrpc.Handle(muxrpc.NewPacker(conn), h,
		muxrpc.WithContext(ctx),
		muxrpc.WithLogger(connLogger),
		// _isServer_ defines _are we a server_.
		// the muxrpc option asks are we _talking_ to a server > inverted
		muxrpc.WithIsServer(!isServer))

	if n.edpWrapper != nil {
		edp = n.edpWrapper(edp)
	}
	n.addRemote(edp)

	srv := edp.(muxrpc.Server)

	err = srv.Serve()
	// level.Warn(n.log).Log("conn", "serve-return", "err", err)
	if err != nil && !neterr.IsConnBrokenErr(err) && !errors.Is(err, context.Canceled) {
		level.Debug(rLogger).Log("conn", "serve exited", "err", err)
	}
	n.removeRemote(edp)

	// panic("serve exited")
	err = edp.Terminate()
	// level.Error(n.log).Log("conn", "serve-defer-terminate", "err", err)
}

// Serve starts the network listener and configured resources like local discovery.
// Canceling the passed context makes the function return. Defers take care of stopping these resources.
func (n *Node) Serve(ctx context.Context, wrappers ...muxrpc.HandlerWrapper) error {
	evtLog := log.With(n.log, "event", "network.Serve")
	// TODO: make multiple listeners (localhost:8008 should not restrict or kill connections)
	lisWrap := netwrap.NewListenerWrapper(n.secretServer.Addr(), append(n.opts.BefreCryptoWrappers, n.secretServer.ConnWrapper())...)
	var err error

	n.listenerLock.Lock()
	n.lis, err = netwrap.Listen(n.opts.ListenAddr, lisWrap)
	if err != nil {
		n.listenerLock.Unlock()
		return fmt.Errorf("error creating listener: %w", err)
	}
	n.lisClose = sync.Once{} // reset once
	close(n.listening)
	n.listenerLock.Unlock()

	defer func() { // refresh listener to re-call
		n.lisClose.Do(func() {
			n.listenerLock.Lock()
			n.lis.Close()
			n.lis = nil
			n.listenerLock.Unlock()
		})
		n.listening = make(chan struct{})
	}()

	if n.localDiscovTx != nil {
		n.localDiscovTx.Start()

		defer n.localDiscovTx.Stop()
	}

	if n.localDiscovRx != nil {
		ch, done := n.localDiscovRx.Notify()
		defer done()
		go func() {
			for a := range ch {
				if is, _ := n.connTracker.Active(a); is {
					//n.log.Log("event", "debug", "msg", "ignoring active", "addr", a.String())
					continue
				}
				err := n.Connect(ctx, a)
				if err == nil {
					continue
				}
				level.Warn(evtLog).Log("msg", "discovery dialback loop exited")
			}
		}()
	}

	// accept in a goroutine so that we can react to context cancel and close the listener
	newConn := make(chan net.Conn)
	go func() {
		defer close(newConn)
		for {
			n.listenerLock.Lock()
			if n.lis == nil {
				n.listenerLock.Unlock()
				return
			}
			n.listenerLock.Unlock()
			conn, err := n.lis.Accept()
			if err != nil {
				if strings.Contains(err.Error(), "use of closed network connection") {
					// yikes way of handling this
					// but means this needs to be restarted anyway
					return
				}

				continue
			}

			newConn <- conn
		}
	}()

	defer level.Debug(n.log).Log("event", "network listen loop exited")
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case conn := <-newConn:
			if conn == nil {
				return nil
			}
			go n.handleConnection(ctx, conn, true, wrappers...)
		}
	}
}

func (n *Node) Connect(ctx context.Context, addr net.Addr) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}
	shsAddr := netwrap.GetAddr(addr, "shs-bs")
	if shsAddr == nil {
		return errors.New("node/connect: expected an address containing an shs-bs addr")
	}

	var pubKey = make(ed25519.PublicKey, ed25519.PublicKeySize)
	if shsAddr, ok := shsAddr.(secretstream.Addr); ok {
		copy(pubKey[:], shsAddr.PubKey)
	} else {
		return errors.New("node/connect: expected shs-bs address to be of type secretstream.Addr")
	}

	conn, err := n.dialer(netwrap.GetAddr(addr, "tcp"), append(n.beforeCryptoConnWrappers,
		n.secretClient.ConnWrapper(pubKey))...)
	if err != nil {
		if conn != nil {
			conn.Close()
		}
		return fmt.Errorf("node/connect: error dialing: %w", err)
	}

	go func(c net.Conn) {
		n.handleConnection(ctx, c, false)
	}(conn)
	return nil
}

// GetListenAddr waits for Serve() to be called!
func (n *Node) GetListenAddr() net.Addr {
	_, ok := <-n.listening
	if !ok {
		return n.lis.Addr()
	}
	level.Error(n.log).Log("msg", "listener not ready")
	return nil
}

func (n *Node) applyConnWrappers(conn net.Conn) (net.Conn, error) {
	for i, cw := range n.afterSecureConnWrappers {
		var err error
		conn, err = cw(conn)
		if err != nil {
			return nil, fmt.Errorf("error applying connection wrapper #%d: %w", i, err)
		}
	}
	return conn, nil
}

func (n *Node) Close() error {
	if n.localDiscovTx != nil {
		n.localDiscovTx.Stop()
	}

	if n.httpLis != nil {
		err := n.httpLis.Close()
		if err != nil {
			return fmt.Errorf("ssb: failed to close http listener: %w", err)
		}
	}
	n.listenerLock.Lock()
	defer n.listenerLock.Unlock()
	if n.lis != nil {
		var closeErr error
		n.lisClose.Do(func() {
			closeErr = n.lis.Close()
		})
		if closeErr != nil && !strings.Contains(closeErr.Error(), "use of closed network connection") {
			return fmt.Errorf("ssb: network node failed to close it's listener: %w", closeErr)
		}
	}

	n.remotesLock.Lock()
	defer n.remotesLock.Unlock()
	for addr, edp := range n.remotes {
		if err := edp.Terminate(); err != nil {
			n.log.Log("event", "failed to terminate endpoint", "addr", addr, "err", err)
		}
	}

	if cnt := n.connTracker.Count(); cnt > 0 {
		n.log.Log("event", "warning", "msg", "still open connections", "count", cnt)
		n.connTracker.CloseAll()
	}

	return nil
}
