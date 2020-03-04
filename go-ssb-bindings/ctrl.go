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
	"golang.org/x/sync/errgroup"
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
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("where", "ssbConnectPeers", "n", count, "err", retErr)
		}
	}()
	lock.Lock()
	if sbot == nil {
		lock.Unlock()
		retErr = ErrNotInitialized
		return false
	}
	lock.Unlock()

	addrs, err := queryAddresses()
	if err != nil {
		retErr = errors.Wrap(err, "querying addresses")
		return false
	}

	newConns := make(chan *addrRow)
	connErrs := make(chan *connectResult, len(addrs))

	var wg errgroup.Group

	wg.Go(makeConnWorker(newConns, connErrs))
	wg.Go(makeConnWorker(newConns, connErrs))
	wg.Go(makeConnWorker(newConns, connErrs))

	for _, row := range addrs {
		newConns <- row
	}
	close(newConns)

	if err := wg.Wait(); err != nil {
		retErr = errors.Wrap(err, "waiting for conn workers")
		return false
	}
	close(connErrs)

	tx, err := viewDB.Begin()
	if err != nil {
		retErr = errors.Wrap(err, "failed to make transaction on viewdb")
		return false
	}

	for res := range connErrs {
		if res.err == nil {
			_, err := tx.Exec(`UPDATE addresses set worked_last=strftime("%Y-%m-%dT%H:%M:%f", 'now') where address_id = ?`, res.row.addrID)
			if err != nil {
				retErr = errors.Wrapf(err, "updateFailed: working pub %d", res.row.addrID)
				return false
			}
			continue
		}

		_, err := tx.Exec(`UPDATE addresses set worked_last=0,last_err=? where address_id = ?`, res.err.Error(), res.row.addrID)
		if err != nil {
			retErr = errors.Wrapf(err, "updateFailed: failing pub %d", res.row.addrID)
			return false
		}
	}

	err = tx.Commit()
	if err != nil {
		retErr = errors.Wrap(err, "failed to commit viewdb transaction")
		return false
	}
	return true
}

type connectResult struct {
	row *addrRow
	err error
}

func makeConnWorker(workCh <-chan *addrRow, connErrs chan<- *connectResult) func() error {
	return func() error {
		for row := range workCh {
			err := sbot.Network.Connect(longCtx, row.addr.WrappedAddr())
			level.Info(log).Log("event", "ssbConnectPeers", "dial", row.addrID, "err", err)
			connErrs <- &connectResult{
				row: row,
				err: err,
			}
		}
		return nil
	}
}

type addrRow struct {
	addrID uint
	addr   *multiserver.NetAddress
}

func queryAddresses() ([]*addrRow, error) {
	var (
		addresses []*addrRow
		i         = 0
		rows      *sql.Rows
		err       error
	)

	rows, err = viewDB.Query(`SELECT address_id, address from addresses where use = true order by worked_last desc LIMIT 12;`)
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
			_, execErr := viewDB.Exec(`UPDATE addresses set use=false,last_err=? where address_id = ?`, err.Error(), id)
			if execErr != nil {
				return nil, errors.Wrapf(execErr, "queryAddresses(%d): failed to update parse error row %d", i, id)
			}
			return nil, errors.Wrapf(err, "queryAddresses(%d): row %d (%q) not a multiserver", i, id, addr)
		}

		addresses = append(addresses, &addrRow{
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

	peerID, err := getAuthorID(tok.Peer)
	if err != nil {
		retErr = err
		return false
	}

	_, err = viewDB.Exec(`INSERT INTO addresses (about_id, address) VALUES (?,?)`, peerID, tok.Address.String())
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

// todo: add make:bool parameter
func getAuthorID(ref ssb.FeedRef) (int64, error) {
	strRef := ref.Ref()
	row := viewDB.QueryRow(`SELECT id FROM authors where key = ?`, strRef)

	var peerID int64
	err := row.Scan(&peerID)
	if err != nil {
		if err != sql.ErrNoRows {
			return -1, err
		}

		res, err := viewDB.Exec(`INSERT INTO authors (key) VALUES (?)`, strRef)
		if err != nil {
			return -1, err
		}
		newID, err := res.LastInsertId()
		if err != nil {
			return -1, err
		}

		peerID = newID
	}
	return peerID, nil
}
