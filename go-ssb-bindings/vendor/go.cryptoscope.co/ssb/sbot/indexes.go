// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/machinebox/progress"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/plugins2"
	"go.cryptoscope.co/ssb/repo"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
)

func MountPlugin(plug ssb.Plugin, mode plugins2.AuthMode) Option {
	return func(s *Sbot) error {
		if wrl, ok := plug.(plugins2.NeedsRootLog); ok {
			wrl.WantRootLog(s.ReceiveLog)
		}

		if wrl, ok := plug.(plugins2.NeedsMultiLog); ok {
			err := wrl.WantMultiLog(s)
			if err != nil {
				return fmt.Errorf("sbot/mount plug: failed to fulfill multilog requirement: %w", err)
			}
		}

		if slm, ok := plug.(repo.SimpleIndexMaker); ok {
			err := MountSimpleIndex(plug.Name(), slm.MakeSimpleIndex)(s)
			if err != nil {
				return fmt.Errorf("sbot/mount plug failed to make simple index: %w", err)
			}
		}

		if mlm, ok := plug.(repo.MultiLogMaker); ok {
			err := MountMultiLog(plug.Name(), mlm.MakeMultiLog)(s)
			if err != nil {
				return fmt.Errorf("sbot/mount plug failed to make multilog: %w", err)
			}
		}

		switch mode {
		case plugins2.AuthPublic:
			s.public.Register(plug)
		case plugins2.AuthMaster:
			s.master.Register(plug)
		case plugins2.AuthBoth:
			s.master.Register(plug)
			s.public.Register(plug)
		}
		return nil
	}
}

func MountMultiLog(name string, fn repo.MakeMultiLog) Option {
	return func(s *Sbot) error {
		mlog, updateSink, err := fn(s.indexStore)
		if err != nil {
			return fmt.Errorf("sbot/index: failed to open idx %s: %w", name, err)
		}
		s.closers.AddCloser(updateSink)
		s.closers.AddCloser(mlog)
		s.serveIndex(name, updateSink)
		s.mlogIndicies[name] = mlog
		return nil
	}
}

func MountSimpleIndex(name string, fn repo.MakeSimpleIndex) Option {
	return func(s *Sbot) error {
		idx, updateSink, err := fn(s.indexStore)
		if err != nil {
			return fmt.Errorf("sbot/index: failed to open idx %s: %w", name, err)
		}
		s.closers.AddCloser(updateSink)
		s.serveIndex(name, updateSink)
		s.simpleIndex[name] = idx
		return nil
	}
}

func (s *Sbot) GetSimpleIndex(name string) (librarian.Index, bool) {
	si, has := s.simpleIndex[name]
	return si, has
}

func (s *Sbot) GetMultiLog(name string) (multilog.MultiLog, bool) {
	ml, has := s.mlogIndicies[name]
	return ml, has
}

func (s *Sbot) GetIndexNamesSimple() []string {
	var simple []string
	for name := range s.simpleIndex {
		simple = append(simple, name)
	}
	return simple
}

func (s *Sbot) GetIndexNamesMultiLog() []string {
	var mlogs []string
	for name := range s.mlogIndicies {
		mlogs = append(mlogs, name)
	}
	return mlogs
}

var _ ssb.Indexer = (*Sbot)(nil)

// WaitUntilIndexesAreSynced blocks until all the index processing is in sync with the rootlog
func (s *Sbot) WaitUntilIndexesAreSynced() {
	s.idxInSync.Wait()
}

// the default is to fill an index with all messages
func (s *Sbot) serveIndex(name string, snk librarian.SinkIndex) {
	s.serveIndexFrom(name, snk, s.ReceiveLog)
}

/* some indexes just require a certain kind of message, like type:contact or type:about.

contactLog, err := s.ByType.Get(librarian.Addr("contact"))
if err != nil { ... }
msgs := mutil.Indirect(s.ReceiveLog, contactLog)
*/
func (s *Sbot) serveIndexFrom(name string, snk librarian.SinkIndex, msgs margaret.Log) {
	s.idxInSync.Add(1)

	s.indexStateMu.Lock()
	s.indexStates[name] = "pending"
	s.indexStateMu.Unlock()

	s.idxDone.Go(func() error {

		src, err := msgs.Query(margaret.Live(false), margaret.SeqWrap(true), snk.QuerySpec())
		if err != nil {
			return fmt.Errorf("sbot index(%s) error querying receiveLog for message backlog: %w", name, err)
		}

		logger := log.With(s.info, "index", name)

		var ps progressSink
		ps.backing = snk

		totalMessages := msgs.Seq()

		ctx, cancel := context.WithCancel(s.rootCtx)
		go func() {
			p := progress.NewTicker(ctx, &ps, int64(totalMessages), 7*time.Second)
			pinfo := log.With(level.Info(logger), "event", "index-progress")
			for remaining := range p {
				// how much time until it's done?
				estDone := remaining.Estimated()
				timeLeft := estDone.Sub(time.Now()).Round(time.Second)

				pinfo.Log("done", remaining.Percent(), "time-left", timeLeft)

				s.indexStateMu.Lock()
				s.indexStates[name] = fmt.Sprintf("%.2f%% (time left:%s)", remaining.Percent(), timeLeft)
				s.indexStateMu.Unlock()
			}
		}()

		err = luigi.Pump(s.rootCtx, &ps, src)
		cancel()
		if errors.Is(err, ssb.ErrShuttingDown) || errors.Is(err, context.Canceled) {
			return nil
		}
		if err != nil {
			s.indexStateMu.Lock()
			s.indexStates[name] = err.Error()
			s.indexStateMu.Unlock()
			level.Warn(logger).Log("event", "index stopped", "err", err)
			return fmt.Errorf("sbot index(%s) update of backlog failed: %w", name, err)
		}
		s.idxInSync.Done()

		if !s.liveIndexUpdates {
			return nil
		}

		src, err = msgs.Query(margaret.Live(true), margaret.SeqWrap(true), snk.QuerySpec())
		if err != nil {
			return fmt.Errorf("sbot index(%s) failed to query receive log for live updates: %w", name, err)
		}

		s.indexStateMu.Lock()
		s.indexStates[name] = "live"
		s.indexStateMu.Unlock()

		err = luigi.Pump(s.rootCtx, snk, src)
		if errors.Is(err, ssb.ErrShuttingDown) || errors.Is(err, context.Canceled) {
			return nil
		}
		if err != nil {
			s.indexStateMu.Lock()
			s.indexStates[name] = err.Error()
			s.indexStateMu.Unlock()
			level.Warn(logger).Log("event", "index stopped", "err", err)
			return fmt.Errorf("sbot index(%s) live update failed: %w", name, err)
		}
		return nil
	})
}

type progressSink struct {
	erred error

	mu sync.Mutex
	n  uint

	backing luigi.Sink
}

var (
	_ luigi.Sink       = &progressSink{}
	_ progress.Counter = &progressSink{}
)

func (p *progressSink) N() int64 {
	p.mu.Lock()
	defer p.mu.Unlock()
	return int64(p.n)
}

func (p *progressSink) Err() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.erred
}

func (ps *progressSink) Pour(ctx context.Context, v interface{}) error {
	ps.mu.Lock()
	defer ps.mu.Unlock()
	if ps.erred != nil {
		return ps.erred
	}

	err := ps.backing.Pour(ctx, v)
	if err != nil {
		ps.erred = err
		return err
	}

	ps.n++
	return nil
}

func (ps progressSink) Close() error { return nil }
