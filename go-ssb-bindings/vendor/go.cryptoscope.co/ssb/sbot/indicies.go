// SPDX-License-Identifier: MIT

package sbot

import (
	"context"
	"fmt"
	"time"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/machinebox/progress"
	"github.com/pkg/errors"
	"go.cryptoscope.co/librarian"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/plugins2"
	"go.cryptoscope.co/ssb/repo"
)

func MountPlugin(plug ssb.Plugin, mode plugins2.AuthMode) Option {
	return func(s *Sbot) error {
		if wrl, ok := plug.(plugins2.NeedsRootLog); ok {
			wrl.WantRootLog(s.RootLog)
		}

		if wrl, ok := plug.(plugins2.NeedsMultiLog); ok {
			err := wrl.WantMultiLog(s)
			if err != nil {
				return errors.Wrap(err, "sbot/mount plug: failed to fulfill multilog requirement")
			}
		}

		if slm, ok := plug.(repo.SimpleIndexMaker); ok {
			err := MountSimpleIndex(plug.Name(), slm.MakeSimpleIndex)(s)
			if err != nil {
				return errors.Wrap(err, "sbot/mount plug failed to make simple index")
			}
		}

		if mlm, ok := plug.(repo.MultiLogMaker); ok {
			err := MountMultiLog(plug.Name(), mlm.MakeMultiLog)(s)
			if err != nil {
				return errors.Wrap(err, "sbot/mount plug failed to make multilog")
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
		mlog, updateSink, err := fn(repo.New(s.repoPath))
		if err != nil {
			return errors.Wrapf(err, "sbot/index: failed to open idx %s", name)
		}
		s.closers.addCloser(mlog)
		s.serveIndex(name, updateSink)
		s.mlogIndicies[name] = mlog
		return nil
	}
}

func MountSimpleIndex(name string, fn repo.MakeSimpleIndex) Option {
	return func(s *Sbot) error {
		idx, updateSink, err := fn(repo.New(s.repoPath))
		if err != nil {
			return errors.Wrapf(err, "sbot/index: failed to open idx %s", name)
		}
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

func (s *Sbot) serveIndex(name string, snk librarian.SinkIndex) {
	s.idxInSync.Add(1)

	s.indexStateMu.Lock()
	s.indexStates[name] = "pending"
	s.indexStateMu.Unlock()

	s.idxDone.Go(func() error {

		src, err := s.RootLog.Query(margaret.Live(false), margaret.SeqWrap(true), snk.QuerySpec())
		if err != nil {
			return errors.Wrapf(err, "sbot index(%s) error querying receiveLog for message backlog", name)
		}

		currentSeqV, err := s.RootLog.Seq().Value()
		if err != nil {
			return err
		}

		var ps progressSink
		ps.backing = snk

		totalMessages := currentSeqV.(margaret.Seq).Seq()

		ctx, cancel := context.WithCancel(s.rootCtx)
		go func() {
			p := progress.NewTicker(ctx, &ps, totalMessages, 3*time.Second)
			pinfo := log.With(level.Info(s.info), "index", name, "event", "index-progress")
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
		if err == ssb.ErrShuttingDown || err == context.Canceled {
			return nil
		}
		if err != nil {
			return errors.Wrapf(err, "sbot index(%s) update of backlog failed", name)
		}
		s.idxInSync.Done()

		if !s.liveIndexUpdates {
			return nil
		}

		src, err = s.RootLog.Query(margaret.Live(true), margaret.SeqWrap(true), snk.QuerySpec())
		if err != nil {
			return errors.Wrapf(err, "sbot index(%s) failed to query receive log for live updates", name)
		}

		s.indexStateMu.Lock()
		s.indexStates[name] = "live"
		s.indexStateMu.Unlock()

		err = luigi.Pump(s.rootCtx, snk, src)
		if err == ssb.ErrShuttingDown || err == context.Canceled {
			return nil
		}
		if err != nil {
			return errors.Wrapf(err, "sbot index(%s) live update failed", name)
		}
		return nil
	})
}

type progressSink struct {
	erred error
	n     uint

	backing luigi.Sink
}

var (
	_ luigi.Sink       = &progressSink{}
	_ progress.Counter = &progressSink{}
)

func (p progressSink) N() int64 { return int64(p.n) }

func (p progressSink) Err() error { return p.erred }

func (ps *progressSink) Pour(ctx context.Context, v interface{}) error {
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

func (ps progressSink) Close() error { return ps.backing.Close() }
