package main

import (
	"context"
	"math"
	"net"
	"runtime"
	"strings"
	"time"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/secretstream"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/invite"
)

import "C"

// ConnectPeer opens a network connection to the remote tcpAddr (host:port)
// pubKey is also in std ssb notation @base64=.ed25519

// returns the number of messages that are new or -1 if a connection couldn't be made

//export ssbConnectPeer
func ssbConnectPeer(quasiMs string) bool {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "ssbConnectPeer", "err", err)
		}
	}()
	lock.Lock()
	if sbot == nil {
		lock.Unlock()
		err = ErrNotInitialized
		return false
	}
	lock.Unlock()

	// TODO: release multiserver package as non-internal
	splits := strings.Split(quasiMs, "::")
	tcpAddr := splits[0]
	pubKey := splits[1]

	pubRef, err := ssb.ParseFeedRef(pubKey)
	if err != nil {
		err = errors.Wrap(err, "pubkey: invalid feedRef")
		return false
	}

	resolved, err := net.ResolveTCPAddr("tcp", tcpAddr)
	if err != nil {
		err = errors.Wrapf(err, "failed to resolve %s", tcpAddr)
		return false
	}

	nwAddr := netwrap.WrapAddr(resolved, secretstream.Addr{PubKey: pubRef.PubKey()})

	err = sbot.Network.Connect(longCtx, nwAddr)
	if err != nil {
		err = errors.Wrapf(err, "connecting to %s failed", pubKey)
		return false
	}
	level.Debug(log).Log("event", "dialed", "addr", nwAddr.String())
	return true
}

//export ssbWaitForNewMessages
func ssbWaitForNewMessages(try int32) int64 {
	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		level.Error(log).Log("event", "ssbWaitForNewMessages", "err", ErrNotInitialized)
		return -1
	}

	var err error
	defer func() {
		if err == nil || err == context.DeadlineExceeded || luigi.IsEOS(err) {
			return
		}
		level.Error(log).Log("event", "ssbWaitForNewMessages", "err", err)
	}()
	seqv, err := sbot.RootLog.Seq().Value()
	if err != nil {
		err = errors.Wrapf(err, "failed to get start sequence of rootLog")
		return -1
	}

	atStart := seqv.(margaret.Seq).Seq()
	level.Debug(log).Log("event", "sync waiting for new message", "atStart", atStart)

	time.Sleep(time.Second)
	try--

	start := time.Now()
	var last = atStart
	for {
		seqv, err = sbot.RootLog.Seq().Value()
		if err != nil {
			err = errors.Wrapf(err, "failed to get current sequence of rootLog")
			return -1
		}
		now := seqv.(margaret.Seq).Seq()
		level.Debug(log).Log("event", "ssbWaitForNewMessages", "new", now-atStart, "try", try)

		if now > last {
			last = now
			time.Sleep(time.Second)
			continue
		}

		if last > atStart {
			break
		}

		if try == 0 {
			break
		}
		time.Sleep(time.Second)
		try--
	}

	newMsgs := last - atStart
	level.Debug(log).Log("event", "ssbWaitForNewMessages", "state", "waited", "new", newMsgs, "atStart", atStart, "try", try, "took", time.Since(start))
	return newMsgs
}

//export ssbDisconnectAllPeers
func ssbDisconnectAllPeers() bool {
	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		return false
	}

	sbot.Network.GetConnTracker().CloseAll()
	level.Debug(log).Log("event", "disconnect")
	runtime.GC()
	return true
}

//export ssbNullContent
func ssbNullContent(author string, sequence uint64) int {
	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		level.Error(log).Log("event", "null content failed", "err", ErrNotInitialized)
		return -1
	}

	ref, err := ssb.ParseFeedRef(author)
	if err != nil {
		level.Error(log).Log("event", "null content failed", "err", err)
		return -1
	}

	if sequence > math.MaxUint32 {
		level.Warn(log).Log("event", "null content failed", "whops", "this is a very long feed")
	}

	err = sbot.NullContent(ref, uint(sequence))
	if err != nil {
		level.Error(log).Log("event", "null content failed", "err", err)
		return -1
	}
	return 0
}

//export ssbNullFeed
func ssbNullFeed(ref string) int {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "ssbNullFeed", "err", err)
		}
	}()

	fr, err := ssb.ParseFeedRef(ref)
	if err != nil {
		err = errors.Wrapf(err, "NullFeed: invalid feed reference")
		return -1
	}

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		err = ErrNotInitialized
		return -1
	}

	if nullErr := sbot.NullFeed(fr); nullErr != nil {
		err = errors.Wrap(nullErr, "NullFeed: bot action failed")
		return -1
	}

	return 0
}

//export ssbInviteAccept
func ssbInviteAccept(token string) bool {
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("where", "ssbInviteAccept", "err", retErr)
		}
	}()

	tok, err := invite.ParseLegacyToken(token)
	if err != nil {
		retErr = err
		return false
	}

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		err = ErrNotInitialized
		return false
	}

	ctx, cancel := context.WithCancel(longCtx)
	err = invite.Redeem(ctx, tok, sbot.KeyPair.Id)
	defer cancel()
	if err != nil {
		retErr = err
		return false
	}

	_, err = sbot.PublishLog.Publish(ssb.NewContactFollow(&tok.Peer))
	if err != nil {
		retErr = err
		return false
	}

	pubMsg, err := invite.NewPubMessageFromToken(tok)
	if err != nil {
		retErr = err
		return false
	}

	_, err = sbot.PublishLog.Publish(pubMsg)
	if err != nil {
		retErr = err
		return false
	}

	return true
}
