package main

import (
	"context"
	"database/sql"
	"fmt"
	"math"
	"os"
	"runtime"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/invite"
	multiserver "go.mindeco.de/ssb-multiserver"
)

import "C"

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

	msAddr, err := multiserver.ParseNetAddress([]byte(quasiMs))
	if err != nil {
		err = errors.Wrapf(err, "parsing passed address failed")
		return false
	}

	err = sbot.Network.Connect(longCtx, msAddr.WrappedAddr())
	if err != nil {
		err = errors.Wrapf(err, "connecting to %q failed", msAddr.String())
		return false
	}
	level.Debug(log).Log("event", "dialed", "addr", msAddr.String())
	return true
}

//export ssbConnectPeers
func ssbConnectPeers(count uint32) bool {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "ssbConnectPeers", "n", count, "err", err)
		}
	}()
	lock.Lock()
	if sbot == nil {
		lock.Unlock()
		err = ErrNotInitialized
		return false
	}
	lock.Unlock()

	addrs, err := queryAddresses(count)
	if err != nil {
		err = errors.Wrap(err, "querying addresses")
		return false
	}

	for i, row := range addrs {
		err = sbot.Network.Connect(longCtx, row.addr.WrappedAddr())
		if err != nil {
			viewDB.Exec(`UPDATE addresses set worked_last=0 where address_id = ?`, row.addrID)
			level.Warn(log).Log("where", "ssbConnectPeers", "dial", i, "err", err)
			continue
		}

		_, err := viewDB.Exec(`UPDATE addresses set worked_last=datetime() where address_id = ?`, row.addrID)
		if err != nil {
			level.Error(log).Log("where", "ssbConnectPeers", "update addr", row.addrID, "err", err)
			return false
		}
	}
	return true
}

type addrRow struct {
	addrID uint
	addr   *multiserver.NetAddress
}

func queryAddresses(limit uint32) ([]addrRow, error) {
	var (
		addresses []addrRow
		i         = 0
		rows      *sql.Rows
		err       error
	)

	rows, err = viewDB.Query(`SELECT address_id, address from addresses where use = true order by worked_last desc LIMIT ?;`, limit)
	if err != nil {
		return nil, errors.Wrap(err, "queryAddresses: sql query failed")
	}
	defer rows.Close()

	for rows.Next() {
		var (
			id   uint
			addr string
		)
		err := rows.Scan(&id, &addr)
		if err != nil {
			return nil, errors.Wrapf(err, "queryAddresses: sql scan of row %d failed", i)
		}

		msAddr, err := multiserver.ParseNetAddress([]byte(addr))
		if err != nil {
			viewDB.Exec(`UPDATE addresses set use=false where address_id = ?`, id)
			return nil, errors.Wrapf(err, "queryAddresses: row %d not a multiserver", i)
		}

		addresses = append(addresses, addrRow{
			addrID: id,
			addr:   msAddr,
		})

		fmt.Fprintf(os.Stderr, "\t\tTODO[debug]: addr%d: %s\n", i, addr)
		i++
	}

	if err := rows.Err(); err != nil {
		level.Error(log).Log("where", "qryAddrs", "err", err)
		return nil, err
	}

	return addresses, nil
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
