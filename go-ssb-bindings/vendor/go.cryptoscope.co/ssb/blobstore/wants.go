// SPDX-License-Identifier: MIT

package blobstore

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"

	"github.com/cryptix/go/logging"
	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/go-kit/kit/metrics"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb"
)

const DefaultMaxSize = 5 * 1024 * 1024

type MaxSize int

var ErrBlobBlocked = errors.New("blobstore: unable to receive blob")

func NewWantManager(log logging.Interface, bs ssb.BlobStore, opts ...interface{}) ssb.WantManager {
	wmgr := &wantManager{
		bs:        bs,
		info:      log,
		wants:     make(map[string]int64),
		blocked:   make(map[string]struct{}),
		procs:     make(map[string]*wantProc),
		available: make(chan *hasBlob),
	}

	for i, o := range opts {
		switch v := o.(type) {
		case metrics.Gauge:
			wmgr.gauge = v
		case metrics.Counter:
			wmgr.evtCtr = v
		case MaxSize:
			wmgr.maxSize = uint(v)
		default:
			if v != nil {
				level.Warn(log).Log("event", "unhandled option", "i", i, "type", fmt.Sprintf("%T", o))
			}
		}
	}

	if wmgr.maxSize == 0 {
		wmgr.maxSize = DefaultMaxSize
	}

	wmgr.promGaugeSet("proc", 0)

	wmgr.wantSink, wmgr.Broadcast = luigi.NewBroadcast()

	bs.Changes().Register(luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if err != nil {
			if luigi.IsEOS(err) {
				return nil
			}
			return err
		}
		wmgr.l.Lock()
		defer wmgr.l.Unlock()

		n, ok := v.(ssb.BlobStoreNotification)
		if !ok {
			return errors.Errorf("blob change: unhandled notification type: %T", v)
		}
		wmgr.promEvent(n.Op.String(), 1)

		if n.Op == ssb.BlobStoreOpPut {
			if _, ok := wmgr.wants[n.Ref.Ref()]; ok {
				delete(wmgr.wants, n.Ref.Ref())

				wmgr.promGaugeSet("nwants", len(wmgr.wants))
			}
		}

		return nil
	}))

	go func() {
	workChan:
		for has := range wmgr.available {
			sz, _ := wmgr.bs.Size(has.Want.Ref)
			if sz > 0 {
				level.Debug(log).Log("msg", "skipping already stored blob")
				continue
			}

			initialFrom := has.Proc.edp.Remote().String()

			// trying the one we got it from first
			err := wmgr.getBlob(has.Proc.rootCtx, has.Proc.edp, has.Want.Ref)
			if err == nil {
				continue
			}

			wmgr.l.Lock()
			// iterate through other open procs and try them
			for remote, proc := range wmgr.procs {
				if remote == initialFrom {
					continue
				}

				err := wmgr.getBlob(proc.rootCtx, proc.edp, has.Want.Ref)
				if err == nil {
					continue workChan
				}
			}
			delete(wmgr.wants, has.Want.Ref.Ref())
			level.Warn(wmgr.info).Log("event", "blob retreive failed", "n", len(wmgr.procs))
			wmgr.l.Unlock()
		}
	}()

	return wmgr
}

type wantManager struct {
	luigi.Broadcast

	bs ssb.BlobStore

	maxSize uint

	// blob references that couldn't be fetched multiple times
	blocked map[string]struct{}

	// our own set of wants
	wants    map[string]int64
	wantSink luigi.Sink

	// the set of peers we interact with
	procs map[string]*wantProc

	available chan *hasBlob

	l sync.Mutex

	info   logging.Interface
	evtCtr metrics.Counter
	gauge  metrics.Gauge
}

func (wmgr *wantManager) getBlob(ctx context.Context, edp muxrpc.Endpoint, ref *ssb.BlobRef) error {
	log := log.With(wmgr.info, "event", "blobs.get", "ref", ref.Ref()[1:5], "remote", edp.Remote().String())

	arg := GetWithSize{ref, wmgr.maxSize}
	src, err := edp.Source(ctx, []byte{}, muxrpc.Method{"blobs", "get"}, arg)
	if err != nil {
		err = errors.Wrap(err, "blob create source failed")
		level.Warn(log).Log("err", err)
		return err
	}

	r := muxrpc.NewSourceReader(src)
	r = io.LimitReader(r, int64(wmgr.maxSize))
	newBr, err := wmgr.bs.Put(r)
	if err != nil {
		err = errors.Wrap(err, "blob data piping failed")
		level.Warn(log).Log("err", err)
		return err
	}

	if !newBr.Equal(ref) {
		// TODO: make this a type of error?
		wmgr.bs.Delete(newBr)
		level.Warn(log).Log("msg", "removed after missmatch", "want", ref.Ref()[1:5])
		return errors.New("blobs: inconsitency(or size limit)")
	}
	sz, _ := wmgr.bs.Size(newBr)
	level.Info(log).Log("msg", "stored", "ref", ref.Ref()[1:5], "sz", sz)
	return nil
}

type hasBlob struct {
	Want ssb.BlobWant
	Proc *wantProc
}

func (wmgr *wantManager) promEvent(name string, n float64) {
	name = "blobs." + name
	if wmgr.evtCtr != nil {
		wmgr.evtCtr.With("event", name).Add(n)
	} else {
		level.Debug(wmgr.info).Log("evt", name, "add", n)
	}
}

func (wmgr *wantManager) promGauge(name string, n float64) {
	name = "blobs." + name
	if wmgr.gauge != nil {
		wmgr.gauge.With("part", name).Add(n)
	} else {
		// level.Debug(wmgr.info).Log("gauge", name, "add", n)
	}
}
func (wmgr *wantManager) promGaugeSet(name string, n int) {
	name = "blobs." + name
	if wmgr.gauge != nil {
		wmgr.gauge.With("part", name).Set(float64(n))
	} else {
		// level.Debug(wmgr.info).Log("gauge", name, "set", n)
	}
}

func (wmgr *wantManager) Close() error {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()
	close(wmgr.available)
	return nil
}

func (wmgr *wantManager) AllWants() []ssb.BlobWant {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()
	var bws []ssb.BlobWant
	for ref, dist := range wmgr.wants {
		br, err := ssb.ParseBlobRef(ref)
		if err != nil {
			panic(errors.Wrap(err, "invalid blob ref in want manager"))
		}
		bws = append(bws, ssb.BlobWant{
			Ref:  br,
			Dist: dist,
		})
	}
	return bws
}

func (wmgr *wantManager) Wants(ref *ssb.BlobRef) bool {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()

	_, ok := wmgr.wants[ref.Ref()]
	return ok
}

func (wmgr *wantManager) Want(ref *ssb.BlobRef) error {
	return wmgr.WantWithDist(ref, -1)
}

func (wmgr *wantManager) WantWithDist(ref *ssb.BlobRef, dist int64) error {
	dbg := log.With(wmgr.info, "func", "WantWithDist", "ref", ref.Ref()[1:5], "dist", dist)
	dbg = level.Debug(dbg)
	_, err := wmgr.bs.Size(ref)
	if err == nil {
		dbg.Log("available", true)
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

	// TODO: ctx?? this pours into the broadcast, right?
	err = wmgr.wantSink.Pour(context.TODO(), ssb.BlobWant{ref, dist})
	err = errors.Wrap(err, "error pouring want to broadcast")
	return err
}

func (wmgr *wantManager) CreateWants(ctx context.Context, sink luigi.Sink, edp muxrpc.Endpoint) luigi.Sink {
	wmgr.l.Lock()
	defer wmgr.l.Unlock()
	err := sink.Pour(ctx, wmgr.wants)
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
		out:         sink,
		remoteWants: make(map[string]int64),
		edp:         edp,
	}

	var remote = "unknown"
	if r, err := ssb.GetFeedRefFromAddr(proc.edp.Remote()); err == nil {
		remote = r.Ref()[1:5]
	}
	proc.info = log.With(proc.wmgr.info, "remote", remote)

	proc.wmgr.promGauge("proc", 1)

	bsCancel := proc.bs.Changes().Register(luigi.FuncSink(proc.updateFromBlobStore))
	wmCancel := proc.wmgr.Register(luigi.FuncSink(proc.updateWants))

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

	bs   ssb.BlobStore
	wmgr *wantManager
	out  luigi.Sink
	done func(func())
	edp  muxrpc.Endpoint

	l           sync.Mutex
	remoteWants map[string]int64
}

// updateFromBlobStore listens for adds and if they are wanted notifies the remote via it's sink
func (proc *wantProc) updateFromBlobStore(ctx context.Context, v interface{}, err error) error {
	dbg := level.Debug(proc.info)
	dbg = log.With(dbg, "event", "blobStoreNotify")
	proc.l.Lock()
	defer proc.l.Unlock()

	if err != nil {
		if luigi.IsEOS(err) {
			return nil
		}
		dbg.Log("cause", "update error", "err", err)
		return errors.Wrap(err, "blobstore broadcast error")
	}

	notif, ok := v.(ssb.BlobStoreNotification)
	if !ok {
		err = errors.Errorf("wantProc: unhandled notification type: %T", v)
		level.Error(proc.info).Log("warning", "invalid type", "err", err)
		return err
	}
	dbg = log.With(dbg, "op", notif.Op.String(), "ref", notif.Ref.Ref()[1:5])

	proc.wmgr.promEvent(notif.Op.String(), 1)

	if _, wants := proc.remoteWants[notif.Ref.Ref()]; !wants {
		return nil
	}

	sz, err := proc.bs.Size(notif.Ref)
	if err != nil {
		return errors.Wrap(err, "error getting blob size")
	}

	m := map[string]int64{notif.Ref.Ref(): sz}
	err = proc.out.Pour(ctx, m)
	dbg.Log("cause", "broadcasting received blob", "sz", sz)
	return errors.Wrap(err, "errors pouring into sink")

}

//
func (proc *wantProc) updateWants(ctx context.Context, v interface{}, err error) error {
	dbg := level.Debug(proc.info)
	if err != nil {
		if luigi.IsEOS(err) {
			return nil
		}
		dbg.Log("cause", "broadcast error", "err", err)
		return errors.Wrap(err, "wmanager broadcast error")
	}
	proc.l.Lock()
	defer proc.l.Unlock()

	w, ok := v.(ssb.BlobWant)
	if !ok {
		err := errors.Errorf("wrong type: %T", v)
		return err
	}
	dbg = log.With(dbg, "event", "wantBroadcast", "ref", w.Ref.Ref()[1:5], "dist", w.Dist)

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
	// TODO: should use rootCtx from sbot?
	return proc.out.Pour(ctx, newW)
}

type GetWithSize struct {
	Key *ssb.BlobRef `json:"key"`
	Max uint         `json:"max"`
}

func (proc *wantProc) Close() error {
	// TODO: unwant open wants
	defer proc.done(nil)
	return errors.Wrap(proc.out.Close(), "error in lower-layer close")
}

func (proc *wantProc) Pour(ctx context.Context, v interface{}) error {
	dbg := level.Debug(proc.info)
	dbg = log.With(dbg, "event", "createWants.In")

	mIn := v.(*WantMsg)
	mOut := make(map[string]int64)

	for _, w := range *mIn {
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
						return errors.Wrap(err, "forwarding want faild")
					}
					continue
				}

				return errors.Wrap(err, "error getting blob size")
			}

			proc.l.Lock()
			delete(proc.remoteWants, w.Ref.Ref())
			proc.l.Unlock()
			mOut[w.Ref.Ref()] = s
		} else {
			if proc.wmgr.Wants(w.Ref) {
				if uint(w.Dist) > proc.wmgr.maxSize {
					dbg.Log("msg", "blob we wanted is larger then our max setting", "ref", w.Ref.Ref()[1:5], "diff", uint(w.Dist)-proc.wmgr.maxSize)
					proc.wmgr.l.Lock()
					delete(proc.wmgr.wants, w.Ref.Ref())
					proc.wmgr.l.Unlock()
					continue
				}

				proc.wmgr.available <- &hasBlob{
					Want: w,
					Proc: proc,
				}
			}
		}
	}

	// shut up if you don't have anything meaningful to add
	if len(mOut) == 0 {
		return nil
	}

	// cryptix: feel like we might need to wrap rootCtx in, too?
	err := proc.out.Pour(ctx, mOut)
	return errors.Wrap(err, "error responding to wants")
}

type WantMsg []ssb.BlobWant

/* turns a blobwant array into one object ala
{
	ref1:dist1,
	ref2:dist2,
	...
}
*/
func (msg WantMsg) MarshalJSON() ([]byte, error) {
	wantsMap := make(map[*ssb.BlobRef]int64, len(msg))
	for _, want := range msg {
		wantsMap[want.Ref] = want.Dist
	}
	data, err := json.Marshal(wantsMap)
	return data, errors.Wrap(err, "WantMsg: error marshalling map?")
}

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
		return errors.Wrap(err, "WantMsg: error parsing into map")
	}

	var wants []ssb.BlobWant
	for ref, dist := range wantsMap {
		br, err := ssb.ParseBlobRef(ref)
		if err != nil {
			return errors.Wrap(err, "WantMsg: error parsing blob reference")
		}

		wants = append(wants, ssb.BlobWant{
			Ref:  br,
			Dist: dist,
		})
	}
	*msg = wants
	return nil
}
