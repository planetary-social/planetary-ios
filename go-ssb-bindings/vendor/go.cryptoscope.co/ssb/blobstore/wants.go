// SPDX-License-Identifier: MIT

package blobstore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/go-kit/kit/metrics"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb/internal/broadcasts"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

// ErrBlobBlocked is returned if the want manager is unable to receive a blob after multiple tries
var ErrBlobBlocked = errors.New("ssb: unable to receive blob correctly")

// NewWantManager returns the configured WantManager, using bs for storage and opts to configure it.
func NewWantManager(bs ssb.BlobStore, opts ...WantManagerOption) *WantManager {
	wmgr := &WantManager{
		bs:        bs,
		info:      log.NewNopLogger(),
		maxSize:   DefaultMaxSize,
		longCtx:   context.Background(),
		wants:     make(map[string]int64),
		blocked:   make(map[string]struct{}),
		procs:     make(map[string]*wantProc),
		available: make(chan *hasBlob),
	}

	for i, o := range opts {
		if err := o(wmgr); err != nil {
			panic(fmt.Errorf("NewWantManager called with invalid option #%d: %w", i, err))
		}
	}

	if wmgr.maxSize == 0 {
		wmgr.maxSize = DefaultMaxSize
	}

	wmgr.promGaugeSet("proc", 0)

	wmgr.wantsEmitter, wmgr.BlobWantsBroadcast = broadcasts.NewBlobWantsEmitter()

	bs.Register(wmgr)

	// once we learn about available blobs from peeers we are connected to
	go func() {
	workChan:
		for has := range wmgr.available {
			sz, _ := wmgr.bs.Size(has.want.Ref)
			if sz > 0 { // already received
				continue
			}

			initialFrom := has.remote.Remote().String()

			// trying the one we got it from first
			err := wmgr.getBlob(has.connCtx, has.remote, has.want.Ref)
			if err == nil {
				continue
			}

			wmgr.l.Lock()
			// iterate through other open procs and try them
			for remote, proc := range wmgr.procs {
				if remote == initialFrom {
					continue
				}
				ctx, cancel := context.WithTimeout(has.connCtx, 3*time.Minute)
				err := wmgr.getBlob(ctx, proc.edp, has.want.Ref)
				cancel()
				if err == nil {
					wmgr.l.Unlock()
					continue workChan
				}
			}
			delete(wmgr.wants, has.want.Ref.Ref())
			level.Warn(wmgr.info).Log("event", "blob retreive failed", "n", len(wmgr.procs))
			wmgr.l.Unlock()
		}
	}()

	return wmgr
}

type WantManager struct {
	*broadcasts.BlobWantsBroadcast

	longCtx context.Context

	bs ssb.BlobStore

	maxSize uint

	// blob references that couldn't be fetched multiple times
	blocked map[string]struct{}

	// our own set of wants
	wants        map[string]int64
	wantsEmitter ssb.BlobWantsEmitter

	// the set of peers we interact with
	procs map[string]*wantProc

	available chan *hasBlob

	l sync.Mutex // TODO: what is this protecting

	info   logging.Interface
	evtCtr metrics.Counter
	gauge  metrics.Gauge
}

func (wmgr *WantManager) EmitBlob(n ssb.BlobStoreNotification) error {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()

	wmgr.promEvent(n.Op.String(), 1)

	// remove wanted blobs on update
	if n.Op == ssb.BlobStoreOpPut {
		if _, ok := wmgr.wants[n.Ref.Ref()]; ok {
			delete(wmgr.wants, n.Ref.Ref())

			wmgr.promGaugeSet("nwants", len(wmgr.wants))
		}
	}

	return nil
}

type hasBlob struct {
	want    ssb.BlobWant
	remote  muxrpc.Endpoint
	connCtx context.Context
}

func (wmgr *WantManager) getBlob(ctx context.Context, edp muxrpc.Endpoint, ref refs.BlobRef) error {
	log := log.With(wmgr.info, "event", "blobs.get", "ref", ref.ShortRef())

	arg := GetWithSize{ref, wmgr.maxSize}
	src, err := edp.Source(ctx, 0, muxrpc.Method{"blobs", "get"}, arg)
	if err != nil {
		err = fmt.Errorf("blob create source failed: %w", err)
		level.Warn(log).Log("err", err)
		return err
	}

	r := muxrpc.NewSourceReader(src)
	r = io.LimitReader(r, int64(wmgr.maxSize))
	newBr, err := wmgr.bs.Put(r)
	if err != nil {
		err = fmt.Errorf("blob data piping failed: %w", err)
		level.Warn(log).Log("err", err)
		return err
	}

	if !newBr.Equal(ref) {
		// TODO: make this a type of error?
		wmgr.bs.Delete(newBr)
		level.Warn(log).Log("msg", "removed after missmatch", "want", ref.ShortRef())
		return errors.New("blobs: inconsitency(or size limit)")
	}
	sz, _ := wmgr.bs.Size(newBr)
	level.Info(log).Log("msg", "stored", "ref", ref.ShortRef(), "sz", sz)
	return nil
}

func (wmgr *WantManager) promEvent(name string, n float64) {
	name = "blobs." + name
	if wmgr.evtCtr != nil {
		wmgr.evtCtr.With("event", name).Add(n)
	}
}

func (wmgr *WantManager) promGauge(name string, n float64) {
	name = "blobs." + name
	if wmgr.gauge != nil {
		wmgr.gauge.With("part", name).Add(n)
	}
}
func (wmgr *WantManager) promGaugeSet(name string, n int) {
	name = "blobs." + name
	if wmgr.gauge != nil {
		wmgr.gauge.With("part", name).Set(float64(n))
	}
}

func (wmgr *WantManager) Close() error {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()
	// TODO: wait for wantproce
	close(wmgr.available)
	return nil
}

func (wmgr *WantManager) AllWants() []ssb.BlobWant {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()
	var bws []ssb.BlobWant
	for ref, dist := range wmgr.wants {
		br, err := refs.ParseBlobRef(ref)
		if err != nil {
			panic(fmt.Errorf("invalid blob ref in want manager: %w", err))
		}
		bws = append(bws, ssb.BlobWant{
			Ref:  br,
			Dist: dist,
		})
	}
	return bws
}

func (wmgr *WantManager) Wants(ref refs.BlobRef) bool {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()

	_, ok := wmgr.wants[ref.Ref()]
	return ok
}

func (wmgr *WantManager) Want(ref refs.BlobRef) error {
	return wmgr.WantWithDist(ref, -1)
}

func (wmgr *WantManager) WantWithDist(ref refs.BlobRef, dist int64) error {
	_, err := wmgr.bs.Size(ref)
	if err == nil {
		return nil
	}

	wmgr.l.Lock()
	defer wmgr.l.Unlock()

	if _, blocked := wmgr.blocked[ref.Ref()]; blocked {
		return ErrBlobBlocked
	}

	if wanteDist, wanted := wmgr.wants[ref.Ref()]; wanted && wanteDist > dist {
		// already wanted higher
		return nil
	}

	wmgr.wants[ref.Ref()] = dist
	wmgr.promGaugeSet("nwants", len(wmgr.wants))

	wmgr.wantsEmitter.EmitWant(ssb.BlobWant{Ref: ref, Dist: dist})
	return nil
}

func (wmgr *WantManager) CreateWants(ctx context.Context, sink *muxrpc.ByteSink, edp muxrpc.Endpoint) luigi.Sink {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()

	sink.SetEncoding(muxrpc.TypeJSON)
	enc := json.NewEncoder(sink)
	err := enc.Encode(wmgr.wants)
	if err != nil {
		if !muxrpc.IsSinkClosed(err) {
			level.Error(wmgr.info).Log("event", "wantProc.init/Pour", "err", err.Error())
		}
		return nil
	}

	proc := &wantProc{
		rootCtx:     ctx,
		bs:          wmgr.bs,
		wmgr:        wmgr,
		out:         enc,
		outSink:     sink,
		remoteWants: make(map[string]int64),
		edp:         edp,
	}

	var remote = "unknown"
	if r, err := ssb.GetFeedRefFromAddr(proc.edp.Remote()); err == nil {
		remote = r.ShortRef()
	}
	proc.info = log.With(proc.wmgr.info, "remote", remote)

	proc.wmgr.promGauge("proc", 1)

	bsCancel := proc.bs.Register(proc)
	wmCancel := proc.wmgr.Register(proc)

	// _i think_ the extra next func is so that the tests can see the shutdown
	oldDone := proc.done
	proc.done = func(next func()) {
		proc.wmgr.promGauge("proc", -1)
		bsCancel()
		wmCancel()
		if oldDone != nil {
			oldDone(nil)
		}
		if next != nil {
			next()
		}
		proc.wmgr.l.Lock()
		delete(proc.wmgr.procs, proc.edp.Remote().String())
		proc.wmgr.l.Unlock()
	}

	wmgr.procs[edp.Remote().String()] = proc

	return proc
}

type wantProc struct {
	rootCtx context.Context

	info log.Logger

	bs      ssb.BlobStore
	wmgr    *WantManager
	out     *json.Encoder
	outSink *muxrpc.ByteSink
	done    func(func())
	edp     muxrpc.Endpoint

	l           sync.Mutex
	remoteWants map[string]int64
}

// updateFromBlobStore listens for adds and if they are wanted notifies the remote via it's sink
func (proc *wantProc) EmitBlob(notif ssb.BlobStoreNotification) error {
	dbg := level.Debug(proc.info)
	dbg = log.With(dbg, "event", "blobStoreNotify")
	proc.l.Lock()
	defer proc.l.Unlock()

	dbg = log.With(dbg, "op", notif.Op.String(), "ref", notif.Ref.ShortRef())
	proc.wmgr.promEvent(notif.Op.String(), 1)

	if _, wants := proc.remoteWants[notif.Ref.Ref()]; !wants {
		return nil
	}

	sz := notif.Size

	m := map[string]int64{notif.Ref.Ref(): sz}
	err := proc.out.Encode(m)
	if err != nil {
		return fmt.Errorf("errors pouring into sink: %w", err)
	}

	dbg.Log("cause", "broadcasting received blob", "sz", sz)
	return nil
}

//
func (proc *wantProc) EmitWant(w ssb.BlobWant) error {
	dbg := level.Debug(proc.info)

	proc.l.Lock()
	defer proc.l.Unlock()

	dbg = log.With(dbg, "event", "wantBroadcast", "ref", w.Ref.ShortRef(), "dist", w.Dist)

	if _, blocked := proc.wmgr.blocked[w.Ref.Ref()]; blocked {
		return nil
	}

	if w.Dist < 0 {
		_, wants := proc.remoteWants[w.Ref.Ref()]
		if wants {
			return nil
		}
	}

	if sz, err := proc.bs.Size(w.Ref); err == nil {
		level.Info(proc.info).Log("local", "has size!", "sz", sz)
		return nil
	}

	newW := WantMsg{w}
	// dbg.Log("op", "sending want we now want", "wantCount", len(proc.wmgr.wants))
	return proc.out.Encode(newW)
}

// GetWithSize is a muxrpc argument helper.
// It can be used to request a blob named _key_ with a different maximum size than the default.
type GetWithSize struct {
	Key refs.BlobRef `json:"key"`
	Max uint         `json:"max"`
}

func (proc *wantProc) Close() error {
	// TODO: unwant open wants
	defer proc.done(nil)
	if err := proc.outSink.Close(); err != nil {
		return fmt.Errorf("error in lower-layer close: %w", err)
	}
	return nil
}

func (proc *wantProc) Pour(ctx context.Context, v interface{}) error {
	dbg := level.Debug(proc.info)
	dbg = log.With(dbg, "event", "createWants.In")

	mIn, ok := v.(WantMsg)
	if !ok {
		return fmt.Errorf("wantProc: unexpected type %T", v)
	}
	mOut := make(map[string]int64)

	for _, w := range mIn {
		if _, blocked := proc.wmgr.blocked[w.Ref.Ref()]; blocked {
			continue
		}

		if w.Dist < 0 {
			if w.Dist < -4 {
				continue // ignore, too far off
			}
			s, err := proc.bs.Size(w.Ref)
			if err != nil {
				if err == ErrNoSuchBlob {
					proc.l.Lock()
					proc.remoteWants[w.Ref.Ref()] = w.Dist
					proc.l.Unlock()

					wErr := proc.wmgr.WantWithDist(w.Ref, w.Dist-1)
					if wErr != nil {
						return fmt.Errorf("forwarding want faild: %w", err)
					}
					continue
				}

				return fmt.Errorf("error getting blob size: %w", err)
			}

			proc.l.Lock()
			delete(proc.remoteWants, w.Ref.Ref())
			proc.l.Unlock()
			mOut[w.Ref.Ref()] = s
		} else {
			if proc.wmgr.Wants(w.Ref) {
				if uint(w.Dist) > proc.wmgr.maxSize {
					proc.wmgr.l.Lock()
					delete(proc.wmgr.wants, w.Ref.Ref())
					proc.wmgr.l.Unlock()
					continue
				}

				proc.wmgr.available <- &hasBlob{
					connCtx: ctx,
					want:    w,
					remote:  proc.edp,
				}
			}
		}
	}

	// shut up if you don't have anything meaningful to add
	if len(mOut) == 0 {
		return nil
	}

	err := proc.out.Encode(mOut)
	if err != nil {
		return fmt.Errorf("error responding to wants: %w", err)
	}
	return nil
}

// WantMsg is an array of _wants_, a blob reference with a distance.
type WantMsg []ssb.BlobWant

// MarshalJSON turns a BlobWant slice into one object.
// for example: { ref1:dist1, ref2:dist2, ... }
func (msg WantMsg) MarshalJSON() ([]byte, error) {
	wantsMap := make(map[string]int64, len(msg))
	for _, want := range msg {
		wantsMap[want.Ref.Ref()] = want.Dist
	}
	data, err := json.Marshal(wantsMap)
	if err != nil {
		return nil, fmt.Errorf("WantMsg: error marshalling map: %w", err)
	}
	return data, nil
}

// UnmarshalJSON turns an object of {ref:dist, ...} relations into a slice of BlobWants.
func (msg *WantMsg) UnmarshalJSON(data []byte) error {
	var directWants []ssb.BlobWant
	err := json.Unmarshal(data, &directWants)
	if err == nil {
		*msg = directWants
		return nil
	}

	var wantsMap map[string]int64
	err = json.Unmarshal(data, &wantsMap)
	if err != nil {
		return fmt.Errorf("WantMsg: error parsing into map: %w", err)
	}

	var wants []ssb.BlobWant
	for ref, dist := range wantsMap {
		br, err := refs.ParseBlobRef(ref)
		if err != nil {
			fmt.Println(fmt.Errorf("WantMsg: error parsing blob reference: %w", err))
			continue
		}

		wants = append(wants, ssb.BlobWant{
			Ref:  br,
			Dist: dist,
		})
	}
	*msg = wants
	return nil
}
