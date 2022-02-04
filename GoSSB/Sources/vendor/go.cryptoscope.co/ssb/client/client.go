// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package client is a a simple muxrpc interface to common ssb methods, similar to npm:ssb-client
package client

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net"
	"os"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	"golang.org/x/crypto/ed25519"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/plugins/whoami"
	refs "go.mindeco.de/ssb-refs"
)

type Client struct {
	muxrpc.Endpoint
	rootCtx       context.Context
	rootCtxCancel context.CancelFunc
	logger        log.Logger

	closer io.Closer

	appKeyBytes []byte
}

func newClientWithOptions(opts []Option) (*Client, error) {
	var c Client
	for i, o := range opts {
		err := o(&c)
		if err != nil {
			return nil, fmt.Errorf("client: option #%d failed: %w", i, err)
		}
	}

	// defaults
	if c.logger == nil {
		defLog := log.With(log.NewLogfmtLogger(os.Stderr), "unit", "ssbClient")
		c.logger = level.NewFilter(defLog, level.AllowInfo())
	}

	if c.rootCtx == nil {
		c.rootCtx = context.TODO()
	}
	c.rootCtx, c.rootCtxCancel = context.WithCancel(c.rootCtx)

	if c.appKeyBytes == nil {
		var err error
		c.appKeyBytes, err = base64.StdEncoding.DecodeString("1KHLiKZvAvjbY1ziZEHMXawbCEIM6qwjCDm3VYRan/s=")
		if err != nil {
			return nil, fmt.Errorf("client: failed to decode default app key: %w", err)
		}
	}

	return &c, nil
}

func FromEndpoint(edp muxrpc.Endpoint, opts ...Option) (*Client, error) {
	c, err := newClientWithOptions(opts)
	if err != nil {
		return nil, err
	}
	panic("TODO: is server?")
	c.Endpoint = edp
	return c, nil
}

func NewTCP(own ssb.KeyPair, remote net.Addr, opts ...Option) (*Client, error) {
	c, err := newClientWithOptions(opts)
	if err != nil {
		return nil, err
	}

	edkp := ssb.EdKeyPair(own)

	shsClient, err := secretstream.NewClient(edkp, c.appKeyBytes)
	if err != nil {
		return nil, fmt.Errorf("ssbClient: error creating secretstream.Client: %w", err)
	}

	// todo: would be nice if netwrap could handle these two steps
	// but then it still needs to have the shsClient somehow
	boxAddr := netwrap.GetAddr(remote, "shs-bs")
	if boxAddr == nil {
		return nil, errors.New("ssbClient: expected an address containing an shs-bs addr")
	}

	var pubKey = make(ed25519.PublicKey, ed25519.PublicKeySize)
	shsAddr, ok := boxAddr.(secretstream.Addr)
	if !ok {
		return nil, errors.New("ssbClient: expected shs-bs address to be of type secretstream.Addr")
	}
	copy(pubKey[:], shsAddr.PubKey)

	conn, err := netwrap.Dial(netwrap.GetAddr(remote, "tcp"), shsClient.ConnWrapper(pubKey))
	if err != nil {
		return nil, fmt.Errorf("error dialing: %w", err)
	}
	c.closer = conn

	h := whoami.New(c.logger, own.ID()).Handler()

	c.Endpoint = muxrpc.Handle(muxrpc.NewPacker(conn), h,
		muxrpc.WithIsServer(true),
		muxrpc.WithContext(c.rootCtx),
		muxrpc.WithRemoteAddr(conn.RemoteAddr()),
	)

	srv, ok := c.Endpoint.(muxrpc.Server)
	if !ok {
		conn.Close()
		return nil, fmt.Errorf("ssbClient: failed to cast handler to muxrpc server (has type: %T)", c.Endpoint)
	}

	go func() {
		err := srv.Serve()
		if err != nil {
			level.Warn(c.logger).Log("event", "muxrpc.Serve exited", "err", err)
		}
		conn.Close()
	}()

	return c, nil
}

func NewUnix(path string, opts ...Option) (*Client, error) {
	c, err := newClientWithOptions(opts)
	if err != nil {
		return nil, err
	}

	conn, err := net.Dial("unix", path)
	if err != nil {
		return nil, fmt.Errorf("ssbClient: failed to open unix path %q", path)
	}
	c.closer = conn

	h := noopHandler{
		logger: c.logger,
	}

	c.Endpoint = muxrpc.Handle(muxrpc.NewPacker(conn), &h,
		muxrpc.WithIsServer(true),
		muxrpc.WithContext(c.rootCtx),
	)

	srv, ok := c.Endpoint.(muxrpc.Server)
	if !ok {
		conn.Close()
		return nil, fmt.Errorf("ssbClient: failed to cast handler to muxrpc server (has type: %T)", c.Endpoint)
	}

	go func() {
		err := srv.Serve()
		if err != nil {
			level.Warn(c.logger).Log("event", "muxrpc.Serve exited", "err", err)
		}
		conn.Close()
	}()

	return c, nil
}

func (c Client) Close() error {
	c.Endpoint.Terminate()
	c.rootCtxCancel()
	c.closer.Close()
	return nil
}

func (c Client) Whoami() (refs.FeedRef, error) {
	var resp message.WhoamiReply
	err := c.Async(c.rootCtx, &resp, muxrpc.TypeJSON, muxrpc.Method{"whoami"})
	if err != nil {
		return refs.FeedRef{}, fmt.Errorf("ssbClient: whoami failed: %w", err)
	}
	return resp.ID, nil
}

func (c Client) ReplicateUpTo() (*muxrpc.ByteSource, error) {
	src, err := c.Source(c.rootCtx, muxrpc.TypeJSON, muxrpc.Method{"replicate", "upto"})
	if err != nil {
		return nil, fmt.Errorf("ssbClient: failed to create stream: %w", err)
	}
	return src, nil
}

func (c Client) BlobsWant(ref refs.BlobRef) error {
	var v interface{}
	err := c.Async(c.rootCtx, &v, muxrpc.TypeJSON, muxrpc.Method{"blobs", "want"}, ref.Sigil())
	if err != nil {
		return fmt.Errorf("ssbClient: blobs.want failed: %w", err)
	}
	level.Debug(c.logger).Log("blob", "wanted", "v", v, "ref", ref.Sigil())
	return nil
}

func (c Client) BlobsHas(ref refs.BlobRef) (bool, error) {
	var has bool
	err := c.Async(c.rootCtx, &has, muxrpc.TypeJSON, muxrpc.Method{"blobs", "want"}, ref.Sigil())
	if err != nil {
		return false, fmt.Errorf("ssbClient: whoami failed: %w", err)
	}
	level.Debug(c.logger).Log("blob", "has", "has", has, "ref", ref.Sigil())
	return has, nil

}

func (c Client) BlobsGet(ref refs.BlobRef) (io.Reader, error) {
	args := blobstore.GetWithSize{Key: ref, Max: blobstore.DefaultMaxSize}
	v, err := c.Source(c.rootCtx, 0, muxrpc.Method{"blobs", "get"}, args)
	if err != nil {
		return nil, fmt.Errorf("ssbClient: blobs.get failed: %w", err)
	}
	level.Debug(c.logger).Log("blob", "got", "ref", ref.Sigil())

	return muxrpc.NewSourceReader(v), nil
}

type NamesGetResult map[string]map[string]string

func (ngr NamesGetResult) GetCommonName(feed refs.FeedRef) (string, bool) {
	namesFor, ok := ngr[feed.Sigil()]
	if !ok {
		return "", false
	}
	selfChosen, ok := namesFor[feed.Sigil()]
	if !ok {
		for about, mapv := range ngr {
			_ = about
			for from, prescribed := range mapv {
				return prescribed, true
				// TODO: check that from is a friend
				_ = from
				break
			}
		}
	}
	return selfChosen, true

}

func (c Client) NamesGet() (NamesGetResult, error) {
	var res NamesGetResult
	err := c.Async(c.rootCtx, &res, muxrpc.TypeJSON, muxrpc.Method{"names", "get"})
	if err != nil {
		return nil, fmt.Errorf("ssbClient: names.get failed: %w", err)
	}
	level.Debug(c.logger).Log("names", "get", "cnt", len(res))
	return res, nil
}

func (c Client) NamesSignifier(ref refs.FeedRef) (string, error) {
	var name string
	err := c.Async(c.rootCtx, &name, muxrpc.TypeString, muxrpc.Method{"names", "getSignifier"}, ref.String())
	if err != nil {
		return "", fmt.Errorf("ssbClient: names.getSignifier failed: %w", err)
	}
	level.Debug(c.logger).Log("names", "getSignifier", "name", name, "ref", ref.String())
	return name, nil
}

func (c Client) NamesImageFor(ref refs.FeedRef) (refs.BlobRef, error) {
	var blobRef string
	err := c.Async(c.rootCtx, &blobRef, muxrpc.TypeString, muxrpc.Method{"names", "getImageFor"}, ref.String())
	if err != nil {
		return refs.BlobRef{}, fmt.Errorf("ssbClient: names.getImageFor failed: %w", err)
	}
	level.Debug(c.logger).Log("names", "getImageFor", "image-blob", blobRef, "feed", ref.String())
	return refs.ParseBlobRef(blobRef)
}

func (c Client) Publish(v interface{}) (refs.MessageRef, error) {
	var resp string
	err := c.Async(c.rootCtx, &resp, muxrpc.TypeString, muxrpc.Method{"publish"}, v)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("ssbClient: publish call failed: %w", err)
	}
	msgRef, err := refs.ParseMessageRef(resp)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("failed to parse new message reference: %w", err)
	}
	return msgRef, nil
}

func (c Client) PrivatePublish(v interface{}, recps ...refs.FeedRef) (refs.MessageRef, error) {
	var recpRefs = make([]string, len(recps))
	for i, ref := range recps {
		recpRefs[i] = ref.String()
	}
	var resp refs.MessageRef
	err := c.Async(c.rootCtx, &resp, muxrpc.TypeJSON, muxrpc.Method{"private", "publish"}, v, recpRefs)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("ssbClient: private.publish call failed: %w", err)
	}
	return resp, nil
}

func (c Client) PrivateRead() (*muxrpc.ByteSource, error) {
	src, err := c.Source(c.rootCtx, muxrpc.TypeJSON, muxrpc.Method{"private", "read"})
	if err != nil {
		return nil, fmt.Errorf("ssbClient: private.read query failed: %w", err)
	}
	return src, nil
}

func (c Client) CreateLogStream(o message.CreateLogArgs) (*muxrpc.ByteSource, error) {
	src, err := c.Source(c.rootCtx, muxrpc.TypeJSON, muxrpc.Method{"createLogStream"}, o)
	if err != nil {
		return nil, fmt.Errorf("ssbClient: failed to create stream: %w", err)
	}
	return src, nil
}

func (c Client) CreateHistoryStream(o message.CreateHistArgs) (*muxrpc.ByteSource, error) {
	src, err := c.Source(c.rootCtx, muxrpc.TypeJSON, muxrpc.Method{"createHistoryStream"}, o)
	if err != nil {
		return nil, fmt.Errorf("ssbClient: failed to create stream (%T): %w", o, err)
	}
	return src, nil
}

func (c Client) MessagesByType(o message.MessagesByTypeArgs) (*muxrpc.ByteSource, error) {
	src, err := c.Source(c.rootCtx, muxrpc.TypeJSON, muxrpc.Method{"messagesByType"}, o)
	if err != nil {
		return nil, fmt.Errorf("ssbClient: failed to create stream (%T): %w", o, err)
	}
	return src, nil
}

func (c Client) TanglesThread(o message.TanglesArgs) (*muxrpc.ByteSource, error) {
	src, err := c.Source(c.rootCtx, muxrpc.TypeJSON, muxrpc.Method{"tangles", "thread"}, o)
	if err != nil {
		return nil, fmt.Errorf("ssbClient/tangles: failed to create stream: %w", err)
	}
	return src, nil
}

// TODO: TanglesHeads

type noopHandler struct{ logger log.Logger }

func (noopHandler) Handled(m muxrpc.Method) bool { return false }

func (h noopHandler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {}

func (h noopHandler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	req.CloseWithError(fmt.Errorf("go-ssb/client: unsupported call"))
}
