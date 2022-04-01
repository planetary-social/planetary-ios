package main

import (
	"context"
	"database/sql"
	"fmt"
	"go.cryptoscope.co/ssb/client"
	refs "go.mindeco.de/ssb-refs"
	"math"
	"runtime"
	"strings"
	"time"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb/invite"
	"go.cryptoscope.co/ssb/repo"
	mksbot "go.cryptoscope.co/ssb/sbot"
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

	if servicePlug == nil {
		return true
	}

	go func() {
		time.Sleep(10 * time.Second)
		tok, ok := servicePlug.HasValidToken()
		if !ok {
			log.Log("noToken", "service plugin: token expired or not retreived yet.")
			return
		}
		log.Log("hasToken", tok)
	}()

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

	addrs, err := queryAddresses(count)
	if err != nil {
		retErr = errors.Wrap(err, "querying addresses")
		return false
	}

	if len(addrs) == 0 {
		_, resetAddrErr := viewDB.Exec(`UPDATE addresses set use=true`)
		retErr = errors.Errorf("no peers available (%v)", resetAddrErr)
		return false
	}

	newConns := make(chan *addrRow)
	connErrs := make(chan *connectResult, len(addrs))

	var wg errgroup.Group

	for n := count/2 + 1; n > 0; n-- {
		wg.Go(makeConnWorker(newConns, connErrs))
	}

	// TODO: make connections until we have as much as we wont
	// the current code will cancel early if all the connections fail
	// would be better if it asked for more addresses and kept trying
	// but this is good enough for now
	for _, row := range addrs {
		newConns <- row
	}
	close(newConns)

	err = wg.Wait()
	close(connErrs)
	if err != nil {
		retErr = errors.Wrap(err, "waiting for conn workers")
		return false
	}

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

		_, err := tx.Exec(`UPDATE addresses set worked_last=0,last_err=?,use=false where address_id = ?`, res.err.Error(), res.row.addrID)
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
			ctx, _ := context.WithTimeout(longCtx, 10*60*time.Second) // kill connections after a while until we have live streaming
			err := sbot.Network.Connect(ctx, row.addr.WrappedAddr())
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

func queryAddresses(count uint32) ([]*addrRow, error) {
	var (
		addresses []*addrRow
		i         = 0
		rows      *sql.Rows
		err       error
	)

	// keep the query failures in a seperate transaction and commit it after the parse
	tx, txErr := viewDB.Begin()
	if txErr != nil {
		return nil, errors.Wrap(txErr, "queryAddresses: failed to make transaction for failures")
	}

	rows, err = tx.Query(`SELECT address_id, address from addresses where use = true order by worked_last desc LIMIT ?;`, count)
	if err != nil {
		tx.Rollback()
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
			_, execErr := tx.Exec(`UPDATE addresses set use=false,last_err=? where address_id = ?`, err.Error(), id)
			if execErr != nil {
				tx.Rollback()
				return nil, errors.Wrapf(execErr, "queryAddresses(%d): failed to update parse error row %d", i, id)
			}
			continue
		}

		addresses = append(addresses, &addrRow{
			addrID: id,
			addr:   msAddr,
		})

		i++
	}

	if err := rows.Err(); err != nil {
		level.Error(log).Log("where", "qryAddrs", "err", err)
		tx.Rollback()
		return nil, err
	}

	commitErr := tx.Commit()
	return addresses, errors.Wrap(commitErr, "broken address record update failed")
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

//export ssbFeedReplicate
func ssbFeedReplicate(ref string, yes bool) {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "ssbFeedReplicate", "err", err)
		}
	}()

	fr, err := refs.ParseFeedRef(ref)
	if err != nil {
		err = errors.Wrapf(err, "replicate: invalid feed reference")
		return
	}

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		err = ErrNotInitialized
		return
	}

	if yes {
		sbot.Replicate(fr)
	} else {
		sbot.DontReplicate(fr)
	}
}

//export ssbFeedBlock
func ssbFeedBlock(ref string, yes bool) {
	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "ssbFeedBlock", "err", err)
		}
	}()

	fr, err := refs.ParseFeedRef(ref)
	if err != nil {
		err = errors.Wrapf(err, "block: invalid feed reference")
		return
	}

	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		err = ErrNotInitialized
		return
	}

	if yes {
		sbot.Block(fr)
	} else {
		sbot.Unblock(fr)
	}
}

//export ssbNullContent
func ssbNullContent(author string, sequence uint64) int {
	lock.Lock()
	defer lock.Unlock()
	if sbot == nil {
		level.Error(log).Log("event", "null content failed", "err", ErrNotInitialized)
		return -1
	}

	ref, err := refs.ParseFeedRef(author)
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

	fr, err := refs.ParseFeedRef(ref)
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

//export ssbDropIndexData
func ssbDropIndexData() bool {
	var retErr error
	defer func() {
		if retErr != nil {
			level.Error(log).Log("where", "ssbDropIndexData", "err", retErr)
		}
	}()

	lock.Lock()
	defer lock.Unlock()
	if sbot != nil {
		retErr = fmt.Errorf("sbot still running")
		return false
	}

	if err := mksbot.DropIndicies(repo.New(repoDir)); err != nil {
		retErr = errors.Wrap(err, "failed to drop index data")
		return false
	}

	return true
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
	err = invite.Redeem(ctx, tok, sbot.KeyPair.ID(), client.WithSHSAppKey(appKey))
	defer cancel()

	if err == nil {
		return true
	}

	// don't throw error if pub is already following user
	if strings.Contains(err.Error(), "already following") {
		return true
	}

	// don't throw error if token was already redeemed by user
	if strings.Contains(err.Error(), "method:invite,use is not in list of allowed methods") {
		return true
	}

	retErr = err
	return false
}

// todo: add make:bool parameter
func getAuthorID(ref refs.FeedRef) (int64, error) {
	strRef := ref.String()

	var peerID int64
	err := viewDB.QueryRow(`SELECT id FROM authors where author = ?`, strRef).Scan(&peerID)
	if err != nil {
		if err != sql.ErrNoRows {
			return -1, errors.Wrap(err, "getAuthorID: find query error")
		}

		res, err := viewDB.Exec(`INSERT INTO authors (author) VALUES (?)`, strRef)
		if err != nil {
			return -1, errors.Wrap(err, "getAuthorID: insert query error")
		}
		newID, err := res.LastInsertId()
		if err != nil {
			return -1, errors.Wrap(err, "getAuthorID: insert result error")
		}

		peerID = newID
	}
	return peerID, nil
}
