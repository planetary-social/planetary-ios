package main

import (
	"bytes"
	"encoding/json"
	"go.cryptoscope.co/ssb/multilogs"
	refs "go.mindeco.de/ssb-refs"
	"net"
	"syscall"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/netwrap"
)

import "C"

//export ssbBotStatus
func ssbBotStatus() *C.char {
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("BotStatus", retErr)
		}
	}()

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		retErr = ErrNotInitialized
		return nil
	}

	status, err := sbot.Status()
	if err != nil {
		retErr = errors.Wrap(err, "failed to get current bot status")
		return nil
	}

	var buf bytes.Buffer
	err = json.NewEncoder(&buf).Encode(status)
	if err != nil {
		retErr = errors.Wrap(err, "failed to encode result")
		return nil
	}

	return C.CString(buf.String())
}

//export ssbOpenConnections
func ssbOpenConnections() uint {
	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		return 0
	}
	return sbot.Network.GetConnTracker().Count()
}

type repoCounts struct {
	Feeds    int    `json:"feeds"`
	Messages int64  `json:"messages"`
	LastHash string `json:"lastHash"`
}

//export ssbRepoStats
func ssbRepoStats() *C.char {
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("RepoStats", retErr)
		}
	}()

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		retErr = ErrNotInitialized
		return nil
	}

	var counts repoCounts

	uf, ok := sbot.GetMultiLog(multilogs.IndexNameFeeds)
	if !ok {
		retErr = errors.Errorf("sbot: missing userFeeds index")
		return nil
	}

	feeds, err := uf.List()
	if err != nil {
		retErr = errors.Wrap(err, "RepoStats: could not get list of feeds")
		return nil
	}

	counts.Feeds = len(feeds)

	sv := sbot.ReceiveLog.Seq()
	counts.Messages = sv
	counts.Messages += 1 // 0-indexed (empty is -1)

	lm, err := sbot.ReceiveLog.Get(sv)
	if err == nil {
		lastMsg, ok := lm.(refs.Message)
		if ok {
			counts.LastHash = lastMsg.Key().String()
		} else {
			level.Warn(log).Log("RepoStats", errors.Wrap(err, "RepoStats: latest message is not ok"))
		}
	} else {
		level.Warn(log).Log("RepoStats", errors.Wrap(err, "RepoStats: could not get the last message hash"))
	}

	statBytes, err := json.Marshal(counts)
	if err != nil {
		retErr = errors.Wrap(err, "RepoStats: failed to get marshal json")
		return nil
	}
	return C.CString(string(statBytes))
}

// a copy of netwrap.Dial
func dialWithOutSigPipe(addr net.Addr, wrappers ...netwrap.ConnWrapper) (net.Conn, error) {
	conn, err := net.Dial(addr.Network(), addr.String())
	if err != nil {
		return nil, errors.Wrap(err, "error dialing")
	}

	if err := ignoreSIGPIPE(conn); err != nil {
		return nil, err
	}

	for _, cw := range wrappers {
		conn, err = cw(conn)
		if err != nil {
			return nil, errors.Wrap(err, "error wrapping connection")
		}
	}

	return conn, nil
}

func disableSigPipeWrapper(c net.Conn) (net.Conn, error) {
	if err := ignoreSIGPIPE(c); err != nil {
		return nil, err
	}
	return c, nil
}

// ignoreSIGPIPE prevents SIGPIPE from being raised on TCP sockets when remote hangs up
// https://stackoverflow.com/questions/32197319/network-code-stopping-with-sigpipe
// See also: https://github.com/golang/go/issues/17393
func ignoreSIGPIPE(c net.Conn) error {
	s, ok := c.(syscall.Conn)
	if !ok {
		return errors.Errorf("IgnoreSigPipe: not a syscallConn: %T", c)
	}
	r, e := s.SyscallConn()
	if e != nil {
		return errors.Wrap(e, "IgnoreSigPipe: Failed to get SyscallConn")
	}
	var setSockErr error
	e = r.Control(func(fd uintptr) {
		intfd := int(fd)
		if e := syscall.SetsockoptInt(intfd, syscall.SOL_SOCKET, syscall.SO_NOSIGPIPE, 1); e != nil {
			setSockErr = errors.Wrap(e, "IgnoreSigPipe: Failed to set SO_NOSIGPIPE")
		}
	})
	if e != nil {
		return errors.Wrap(e, "IgnoreSigPipe: Failed to set SO_NOSIGPIPE")
	}
	if setSockErr != nil {
		return setSockErr
	}
	return nil
}
