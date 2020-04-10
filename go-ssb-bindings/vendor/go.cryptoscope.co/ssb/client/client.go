// SPDX-License-Identifier: MIT

package client

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"os"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/muxrpc/codec"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/plugins/whoami"
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
			return nil, errors.Wrapf(err, "client: option #%d failed", i)
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
			return nil, errors.Wrapf(err, "client: failed to decode default app key")
		}
	}

	return &c, nil
}

func FromEndpoint(edp muxrpc.Endpoint, opts ...Option) (*Client, error) {
	c, err := newClientWithOptions(opts)
	if err != nil {
		return nil, err
	}

	c.Endpoint = edp
	return c, nil
}

func NewTCP(own *ssb.KeyPair, remote net.Addr, opts ...Option) (*Client, error) {
	c, err := newClientWithOptions(opts)
	if err != nil {
		return nil, err
	}

	shsClient, err := secretstream.NewClient(own.Pair, c.appKeyBytes)
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: error creating secretstream.Client")
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
		return nil, errors.Wrap(err, "error dialing")
	}
	c.closer = conn

	h := whoami.New(c.logger, own.Id).Handler()

	c.Endpoint = muxrpc.HandleWithRemote(muxrpc.NewPacker(conn), h, conn.RemoteAddr())

	srv, ok := c.Endpoint.(muxrpc.Server)
	if !ok {
		conn.Close()
		return nil, errors.Errorf("ssbClient: failed to cast handler to muxrpc server (has type: %T)", c.Endpoint)
	}

	go func() {
		err := srv.Serve(c.rootCtx)
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
		return nil, errors.Errorf("ssbClient: failed to open unix path %q", path)
	}
	c.closer = conn

	h := noopHandler{
		logger: c.logger,
	}

	c.Endpoint = muxrpc.Handle(muxrpc.NewPacker(conn), &h)

	srv, ok := c.Endpoint.(muxrpc.Server)
	if !ok {
		conn.Close()
		return nil, errors.Errorf("ssbClient: failed to cast handler to muxrpc server (has type: %T)", c.Endpoint)
	}

	go func() {
		err := srv.Serve(c.rootCtx)
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

func (c Client) Whoami() (*ssb.FeedRef, error) {
	v, err := c.Async(c.rootCtx, message.WhoamiReply{}, muxrpc.Method{"whoami"})
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: whoami failed")
	}
	resp, ok := v.(message.WhoamiReply)
	if !ok {
		return nil, errors.Errorf("ssbClient: wrong response type: %T", v)
	}
	return resp.ID, nil
}

func (c Client) ReplicateUpTo() (luigi.Source, error) {
	src, err := c.Source(c.rootCtx, ssb.ReplicateUpToResponse{}, muxrpc.Method{"replicate", "upto"})
	return src, errors.Wrap(err, "ssbClient: failed to create stream")
}

func (c Client) BlobsWant(ref ssb.BlobRef) error {
	var v interface{}
	v, err := c.Async(c.rootCtx, v, muxrpc.Method{"blobs", "want"}, ref.Ref())
	if err != nil {
		return errors.Wrap(err, "ssbClient: blobs.want failed")
	}
	c.logger.Log("blob", "wanted", "v", v, "ref", ref.Ref())
	return nil
}

func (c Client) BlobsHas(ref *ssb.BlobRef) (bool, error) {
	v, err := c.Async(c.rootCtx, true, muxrpc.Method{"blobs", "want"}, ref.Ref())
	if err != nil {
		return false, errors.Wrap(err, "ssbClient: whoami failed")
	}
	c.logger.Log("blob", "has", "v", v, "ref", ref.Ref())
	return v.(bool), nil

}

func (c Client) BlobsGet(ref *ssb.BlobRef) (io.Reader, error) {
	args := blobstore.GetWithSize{Key: ref, Max: blobstore.DefaultMaxSize}
	v, err := c.Source(c.rootCtx, codec.Body{}, muxrpc.Method{"blobs", "get"}, args)
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: blobs.get failed")
	}
	c.logger.Log("blob", "got", "ref", ref.Ref())

	return muxrpc.NewSourceReader(v), nil
}

type NamesGetResult map[string]map[string]string

func (ngr NamesGetResult) GetCommonName(feed *ssb.FeedRef) (string, bool) {
	namesFor, ok := ngr[feed.Ref()]
	if !ok {
		return "", false
	}
	selfChosen, ok := namesFor[feed.Ref()]
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
	v, err := c.Async(c.rootCtx, NamesGetResult{}, muxrpc.Method{"names", "get"})
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: names.get failed")
	}
	c.logger.Log("names", "get", "v", fmt.Sprintf("%T", v))
	res := v.(NamesGetResult)
	return res, nil
}

func (c Client) NamesSignifier(ref ssb.FeedRef) (string, error) {
	var v interface{}
	v, err := c.Async(c.rootCtx, "str", muxrpc.Method{"names", "getSignifier"}, ref.Ref())
	if err != nil {
		return "", errors.Wrap(err, "ssbClient: names.getSignifier failed")
	}
	c.logger.Log("names", "getSignifier", "v", v, "ref", ref.Ref())
	return v.(string), nil
}

func (c Client) NamesImageFor(ref ssb.FeedRef) (*ssb.BlobRef, error) {
	var v interface{}
	v, err := c.Async(c.rootCtx, "str", muxrpc.Method{"names", "getImageFor"}, ref.Ref())
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: names.getImageFor failed")
	}
	c.logger.Log("names", "getImageFor", "v", v, "ref", ref.Ref())
	blobRef := v.(string)
	if blobRef == "" {
		return nil, errors.Errorf("no image for feed")
	}
	return ssb.ParseBlobRef(blobRef)
}

func (c Client) Publish(v interface{}) (*ssb.MessageRef, error) {
	v, err := c.Async(c.rootCtx, "str", muxrpc.Method{"publish"}, v)
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: publish call failed")
	}
	resp, ok := v.(string)
	if !ok {
		return nil, errors.Errorf("ssbClient: wrong reply type: %T", v)
	}
	msgRef, err := ssb.ParseMessageRef(resp)
	return msgRef, errors.Wrap(err, "failed to parse new message reference")
}

func (c Client) PrivatePublish(v interface{}, recps ...*ssb.FeedRef) (*ssb.MessageRef, error) {
	var recpRefs = make([]string, len(recps))
	for i, ref := range recps {
		if ref == nil {
			return nil, errors.Errorf("ssbClient: bad call - recp%d is nil", i)
		}
		recpRefs[i] = ref.Ref()
	}
	v, err := c.Async(c.rootCtx, "str", muxrpc.Method{"private", "publish"}, v, recpRefs)
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: private.publish call failed")
	}
	resp, ok := v.(string)
	if !ok {
		return nil, errors.Errorf("ssbClient: wrong reply type: %T", v)
	}
	msgRef, err := ssb.ParseMessageRef(resp)
	return msgRef, errors.Wrapf(err, "failed to parse new message reference: %q", resp)
}

func (c Client) PrivateRead() (luigi.Source, error) {
	src, err := c.Source(c.rootCtx, ssb.KeyValueRaw{}, muxrpc.Method{"private", "read"})
	if err != nil {
		return nil, errors.Wrap(err, "ssbClient: private.read query failed")
	}
	return src, nil
}

func (c Client) CreateLogStream(opts message.CreateLogArgs) (luigi.Source, error) {
	src, err := c.Source(c.rootCtx, opts.MarshalType, muxrpc.Method{"createLogStream"}, opts)
	return src, errors.Wrapf(err, "ssbClient: failed to create stream (%T)", opts)
}

func (c Client) CreateHistoryStream(o message.CreateHistArgs) (luigi.Source, error) {
	src, err := c.Source(c.rootCtx, o.MarshalType, muxrpc.Method{"createHistoryStream"}, o)
	return src, errors.Wrapf(err, "ssbClient: failed to create stream (%T)", o)
}

func (c Client) MessagesByType(opts message.MessagesByTypeArgs) (luigi.Source, error) {
	src, err := c.Source(c.rootCtx, opts.MarshalType, muxrpc.Method{"messagesByType"}, opts)
	return src, errors.Wrapf(err, "ssbClient: failed to create stream (%T)", opts)
}

func (c Client) Tangles(o message.TanglesArgs) (luigi.Source, error) {
	src, err := c.Source(c.rootCtx, o.MarshalType, muxrpc.Method{"tangles"}, o)
	return src, errors.Wrap(err, "ssbClient/tangles: failed to create stream")
}

type noopHandler struct {
	logger log.Logger
}

func (h noopHandler) HandleConnect(ctx context.Context, edp muxrpc.Endpoint) {
}

func (h noopHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	req.Stream.CloseWithError(fmt.Errorf("go-ssb/client: unsupported call"))
}
