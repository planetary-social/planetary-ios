// SPDX-License-Identifier: MIT

package muxrpc

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"os"
	"strings"
	"sync"

	"github.com/karrick/bufpool"
	"github.com/pkg/errors"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/muxrpc/v2/codec"
)

// HandleOption are used to configure rpc handler instances
type HandleOption func(*rpc)

// WithContext sets the context for the whole lifetime of the rpc session
func WithContext(ctx context.Context) HandleOption {
	return func(r *rpc) {
		r.serveCtx = ctx
	}
}

// WithRemoteAddr also sets the remote address the endpoint is connected to.
// ie if the packer tunnels through something which can't see the address.
func WithRemoteAddr(addr net.Addr) HandleOption {
	return func(r *rpc) {
		r.remote = addr
	}
}

// WithLogger let's you overwrite the stderr logger
func WithLogger(l log.Logger) HandleOption {
	return func(r *rpc) {
		r.logger = l
	}
}

// WithIsServer sets wether the Handle should be in the server (true) or client (false) role
func WithIsServer(yes bool) HandleOption {
	return func(r *rpc) {
		r.isServer = yes
	}
}

// IsServer tells you if the passed endpoint is in the server-role or not.
// i.e.: Did I call the remote: yes.
// Was I called by the remote: no.
// Q: don't want to extend Endpoint interface?
func IsServer(edp Endpoint) bool {
	rpc, ok := edp.(*rpc)
	if !ok {
		panic(fmt.Sprintf("not an *rpc: %T", edp))
	}

	return rpc.isServer
}

// Handle handles the connection of the packer using the specified handler.
func Handle(pkr *Packer, handler Handler, opts ...HandleOption) Endpoint {
	r := &rpc{
		pkr:        pkr,
		reqs:       make(map[int32]*Request),
		reqsClosed: make(map[int32]struct{}),
		root:       handler,
	}

	// apply options
	for _, o := range opts {
		o(r)
	}

	// defaults
	if r.logger == nil {
		logger := log.NewLogfmtLogger(os.Stderr)
		logger = level.NewFilter(logger, level.AllowInfo()) // only log info and above
		r.logger = log.With(logger, "ts", log.DefaultTimestampUTC, "unit", "muxrpc")
	}

	if r.remote == nil {
		if ra, ok := pkr.c.(interface{ RemoteAddr() net.Addr }); ok {
			r.remote = ra.RemoteAddr()
		}
	}

	if r.remote != nil {
		// TODO: retract remote address
		r.logger = log.With(r.logger, "remote", r.remote.String())
	}

	if r.serveCtx == nil {
		r.serveCtx = context.Background()
	}

	bp, err := bufpool.NewChanPool()
	if err != nil {
		panic(err)
	}
	r.bpool = bp

	// we need to be able to cancel in any case
	r.serveCtx, r.cancel = context.WithCancel(r.serveCtx)

	// assume we dont have a manifest
	r.manifest.mu = new(sync.Mutex)
	r.manifest.missing = true
	manifestDone := make(chan struct{})
	go func() {
		r.retreiveManifest()
		close(manifestDone)
	}()

	// start serving
	r.serveErrc = make(chan error)
	go func() {
		r.serveErrc <- r.serve()
	}()

	<-manifestDone

	go handler.HandleConnect(r.serveCtx, r)

	return r
}

// no args should be handled as empty array not args: null
func marshalCallArgs(args []interface{}) ([]byte, error) {
	var argData []byte
	if len(args) == 0 {
		argData = []byte("[]")
	} else {
		var err error
		argData, err = json.Marshal(args)
		if err != nil {
			return nil, fmt.Errorf("error marshaling request arguments: %w", err)
		}
	}
	return argData, nil
}

var (
	_ Endpoint = (*rpc)(nil)
	_ Server   = (*rpc)(nil)
)

// rpc implements an Endpoint, but also implements Server
type rpc struct {
	logger log.Logger

	remote net.Addr

	isServer bool // is this rpc endpoint in the server role?

	// pkr (un)marshales codec.Packets
	pkr *Packer

	bpool bufpool.FreeList

	// reqs is the map we keep, tracking all requests
	reqs map[int32]*Request
	// reqs we didnt accept still might send data
	// like duplex or sink, the remote might send early data before we even get a chance to send an EndErr
	reqsClosed map[int32]struct{}
	rLock      sync.RWMutex

	// highest is the highest request id we already allocated
	highest int32

	root Handler

	// terminated indicates that the rpc session is being terminated
	terminated bool
	tLock      sync.Mutex

	serveErrc chan error
	serveCtx  context.Context
	cancel    context.CancelFunc

	manifest manifestStruct
}

var errSkip = errors.New("mxurpc: skip packet")

// we might receive data for requests we chose to not handle
func (r *rpc) maybeDiscardPacket(hdr codec.Header) error {
	r.rLock.RLock()
	defer r.rLock.RUnlock()
	if _, ignore := r.reqsClosed[hdr.Req]; ignore {
		rd := r.pkr.r.NextBodyReader(hdr.Len)
		_, err := io.Copy(ioutil.Discard, rd)
		if err != nil {
			return err
		}
		return errSkip
	}
	return nil
}

// fetchRequest returns the request from the reqs map or, if it's not there yet, builds a new one.
func (r *rpc) fetchRequest(ctx context.Context, hdr *codec.Header) (*Request, bool, error) {
	var err error

	r.rLock.RLock()

	// get request from the map of active requests, otherwise make new one
	req, exists := r.reqs[hdr.Req]
	if exists {
		r.rLock.RUnlock()
		return req, false, nil
	}

	r.rLock.RUnlock()
	r.rLock.Lock()
	defer r.rLock.Unlock()

	ctx, req, err = r.parseNewRequest(hdr, ctx)
	if err != nil {
		return nil, false, err
	}

	// check if we handle the method and if not, mark the request as closed for potentially incoming data for that request
	if !r.root.Handled(req.Method) {
		errPkt, err := newEndErrPacket(hdr.Req, hdr.Flag.Get(codec.FlagStream), ErrNoSuchMethod{req.Method})
		if err != nil {
			return nil, false, err
		}
		err = r.pkr.w.WritePacket(errPkt)
		if err != nil {
			return nil, false, err
		}
		r.reqsClosed[hdr.Req] = struct{}{}
		// it is a new call in that there is nothing else to do
		return nil, true, nil
	}

	// add the request to the map of active requests
	r.reqs[hdr.Req] = req

	// TODO:
	// buffer new requests to not mindlessly spawn goroutines
	// and prioritize exisitng requests to unblock the connection time
	// maybe use two maps
	go func() {
		r.root.HandleCall(ctx, req)
		level.Debug(r.logger).Log("call", "returned", "method", req.Method, "reqID", req.id)
	}()

	return req, true, nil
}

// parseNewRequest parses the first packet of a stream and parses the contained request
func (r *rpc) parseNewRequest(pkt *codec.Header, sessionCtx context.Context) (context.Context, *Request, error) {
	if pkt.Req >= 0 {
		// request numbers should have been inverted by now
		return nil, nil, fmt.Errorf("new request %d: expected negative request id", pkt.Req)
	}

	// the description of a call (what methods and args) is always JSON
	if !pkt.Flag.Get(codec.FlagJSON) {
		return nil, nil, fmt.Errorf("new request %d: expected JSON flag for new call, got %s", pkt.Req, pkt.Flag)
	}

	// decode the json body of the new request
	rd := r.pkr.r.NextBodyReader(pkt.Len)

	var req Request
	err := json.NewDecoder(rd).Decode(&req)
	if err != nil {
		return nil, nil, fmt.Errorf("new request %d: error decoding packet: %w", pkt.Req, err)
	}

	// initialize the other fields of the request
	req.remoteAddr = r.remote
	req.endpoint = r

	req.id = pkt.Req // copy the request id

	// prepare for shutting it down
	reqCtx, reqCancel := context.WithCancel(sessionCtx)
	req.abort = reqCancel

	// initialize sending and receiving sides of the stream
	req.sink = newByteSink(reqCtx, r.pkr.w)
	req.sink.pkt.Req = req.id

	req.source = newByteSource(reqCtx, r.bpool)

	// legacy streams (TODO: remove these)
	if pkt.Flag.Get(codec.FlagStream) {
		req.sink.pkt.Flag = req.sink.pkt.Flag.Set(codec.FlagStream)
		switch req.Type {
		case "duplex":
			req.Stream = &streamDuplex{src: req.source.AsStream(), snk: req.sink.AsStream()}
		case "source":
			req.Stream = req.sink.AsStream()
		case "sink":
			req.Stream = req.source.AsStream()
		default:
			return nil, nil, fmt.Errorf("new request %d: unhandled request type: %q", req.id, req.Type)
		}
	} else {
		if req.Type == "" {
			req.Type = "async"
		}
		if req.Type != "async" {
			return nil, nil, fmt.Errorf("new request %d: unhandled request type: %q", req.id, req.Type)
		}
		req.Stream = req.sink.AsStream()
	}

	level.Debug(r.logger).Log("event", "got request", "reqID", req.id, "method", req.Method, "type", req.Type)

	return reqCtx, &req, nil
}

// Server can handle packets to and from a remote party
type Server interface {
	Remote() net.Addr
	Serve() error
}

// Serve drains the incoming packets and handles the RPC session
func (r *rpc) Serve() error {
	return <-r.serveErrc
}

func (r *rpc) serve() (err error) {
	level.Debug(r.logger).Log("event", "serving")
	defer func() {
		if isAlreadyClosed(err) {
			err = nil
		}
		cerr := r.Terminate()
		if err != nil && !strings.Contains(err.Error(), "use of closed network connection") {
			level.Error(r.logger).Log(
				"event", "closed",
				"handleErr", err,
				"closeErr", cerr)
		}
	}()

	for {
		var hdr codec.Header

		// read next packet from connection
		doRet := func() bool {
			err = r.pkr.NextHeader(r.serveCtx, &hdr)
			if isAlreadyClosed(err) {
				err = nil
				return true
			}

			if err != nil {
				r.tLock.Lock()
				defer r.tLock.Unlock()

				if r.terminated {
					err = nil
					return true
				}
				err = fmt.Errorf("muxrpc: serve failed to read from packer: %w", err)
				return true
			}

			return false
		}()
		if doRet {
			return
		}

		// error/endstream handling and cleanup
		if hdr.Flag.Get(codec.FlagEndErr) {
			getReq := func(req int32) (*Request, bool) {
				r.rLock.RLock()
				defer r.rLock.RUnlock()

				r, ok := r.reqs[req]
				return r, ok
			}

			// get the request for this new packet
			req, ok := getReq(hdr.Req)
			if !ok {
				err = r.maybeDiscardPacket(hdr)
				if err != nil {
					if err == errSkip {
						continue
					}
					return err
				}
				level.Warn(r.logger).Log("event", "unhandled packet", "reqID", hdr.Req, "len", hdr.Len, "flags", hdr.Flag)
				continue
			}

			buf := r.bpool.Get()

			err = r.pkr.r.ReadBodyInto(buf, hdr.Len)
			if err != nil {
				return fmt.Errorf("muxrpc: failed to get error body for closing of req: %d (len:%d): %w", hdr.Req, hdr.Len, err)
			}

			body := buf.Bytes()
			r.bpool.Put(buf)

			var streamErr error
			if !isTrue(body) {
				streamErr, err = parseError(body)
				if err != nil {
					return fmt.Errorf("error parsing error packet: %w", err)
				}
			}

			r.closeStream(req, streamErr)
			continue
		}

		// data muxing
		err = r.maybeDiscardPacket(hdr)
		if err != nil {
			if err == errSkip {
				continue
			}
			return err
		}

		// pick the requests or create a new one
		var (
			isNew bool
			req   *Request
		)
		req, isNew, err = r.fetchRequest(r.serveCtx, &hdr)
		if err != nil {
			return fmt.Errorf("muxrpc: error unpacking request: %w", err)
		}

		if isNew { // the first packet is just the request data, nothing else to do
			continue
		}

		err = req.source.consume(hdr.Len, hdr.Flag, r.pkr.r.NextBodyReader(hdr.Len))
		if err != nil {
			level.Warn(r.logger).Log(
				"event", "consume failed",
				"req", hdr.Req,
				"method", req.Method.String(),
				"err", err)
			r.closeStream(req, err)
			continue
		}
	}
}

func isTrue(data []byte) bool {
	return len(data) == 4 &&
		data[0] == 't' &&
		data[1] == 'r' &&
		data[2] == 'u' &&
		data[3] == 'e'
}

func (r *rpc) closeStream(req *Request, streamErr error) {
	req.source.Cancel(streamErr)
	req.sink.CloseWithError(streamErr)
	req.abort()

	r.rLock.Lock()
	defer r.rLock.Unlock()
	delete(r.reqs, req.id)
	r.reqsClosed[req.id] = struct{}{}
	return
}

// Terminate ends the RPC session
func (r *rpc) Terminate() error {
	r.cancel()
	r.tLock.Lock()
	defer r.tLock.Unlock()
	r.terminated = true

	// close active requests
	r.rLock.Lock()
	defer r.rLock.Unlock()
	for _, req := range r.reqs {
		req.source.Cancel(ErrSessionTerminated)
		req.sink.CloseWithError(ErrSessionTerminated)
		delete(r.reqs, req.id)
		r.reqsClosed[req.id] = struct{}{}
	}
	return r.pkr.Close()
}

func (r *rpc) Remote() net.Addr {
	return r.remote
}
