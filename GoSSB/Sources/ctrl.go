package main

import "C"
import (
	"context"
	"encoding/json"
	"github.com/planetary-social/scuttlego/service/app/queries"
	"github.com/planetary-social/scuttlego/service/domain/network"
	"github.com/planetary-social/scuttlego/service/domain/refs"
	"github.com/planetary-social/scuttlego/service/domain/rooms/aliases"
	multiserver "go.mindeco.de/ssb-multiserver"
	"time"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
	"github.com/planetary-social/scuttlego/service/domain/invites"
)

// typedef struct ssbRoomsAliasRegisterReturn {
// char* alias;
// int err;
// } ssbRoomsAliasRegisterReturn_t;
import "C"

//export ssbConnectPeer
func ssbConnectPeer(quasiMs string) bool {
	var err error
	defer logError("ssbConnectPeer", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	addr, identity, err := multiserverAddressToAddressAndRef(quasiMs)
	if err != nil {
		err = errors.Wrapf(err, "error parsing the address '%s'", quasiMs)
		return false
	}

	cmd := commands.Connect{
		Remote:  identity.Identity(),
		Address: addr,
	}

	err = service.App.Commands.Connect.Handle(cmd)
	if err != nil {
		err = errors.Wrapf(err, "connecting to '%s' failed", quasiMs)
		return false
	}

	return true
}

//export ssbConnectPeers
func ssbConnectPeers(count uint32) bool {
	//var retErr error
	//defer func() {
	//	if retErr != nil {
	//		level.Error(log).Log("where", "ssbConnectPeers", "n", count, "err", retErr)
	//	}
	//}()
	//lock.Lock()
	//if sbot == nil {
	//	lock.Unlock()
	//	retErr = ErrNotInitialized
	//	return false
	//}
	//lock.Unlock()
	//
	//addrs, err := queryAddresses(count)
	//if err != nil {
	//	retErr = errors.Wrap(err, "querying addresses")
	//	return false
	//}
	//
	//if len(addrs) == 0 {
	//	_, resetAddrErr := viewDB.Exec(`UPDATE addresses set use=true`)
	//	retErr = errors.Errorf("no peers available (%v)", resetAddrErr)
	//	return false
	//}
	//
	//newConns := make(chan *addrRow)
	//connErrs := make(chan *connectResult, len(addrs))
	//
	//var wg errgroup.Group
	//
	//for n := count/2 + 1; n > 0; n-- {
	//	wg.Go(makeConnWorker(newConns, connErrs))
	//}
	//
	//// TODO: make connections until we have as much as we wont
	//// the current code will cancel early if all the connections fail
	//// would be better if it asked for more addresses and kept trying
	//// but this is good enough for now
	//for _, row := range addrs {
	//	newConns <- row
	//}
	//close(newConns)
	//
	//err = wg.Wait()
	//close(connErrs)
	//if err != nil {
	//	retErr = errors.Wrap(err, "waiting for conn workers")
	//	return false
	//}
	//
	//tx, err := viewDB.Begin()
	//if err != nil {
	//	retErr = errors.Wrap(err, "failed to make transaction on viewdb")
	//	return false
	//}
	//
	//for res := range connErrs {
	//	if res.err == nil {
	//		_, err := tx.Exec(`UPDATE addresses set worked_last=strftime("%Y-%m-%dT%H:%M:%f", 'now') where address_id = ?`, res.row.addrID)
	//		if err != nil {
	//			retErr = errors.Wrapf(err, "updateFailed: working pub %d", res.row.addrID)
	//			return false
	//		}
	//		continue
	//	}
	//
	//	_, err := tx.Exec(`UPDATE addresses set worked_last=0,last_err=?,use=false where address_id = ?`, res.err.Error(), res.row.addrID)
	//	if err != nil {
	//		retErr = errors.Wrapf(err, "updateFailed: failing pub %d", res.row.addrID)
	//		return false
	//	}
	//}
	//
	//err = tx.Commit()
	//if err != nil {
	//	retErr = errors.Wrap(err, "failed to commit viewdb transaction")
	//	return false
	//}
	return true // todo
}

//type connectResult struct {
//	row *addrRow
//	err error
//}
//
//func makeConnWorker(workCh <-chan *addrRow, connErrs chan<- *connectResult) func() error {
//	return func() error {
//		for row := range workCh {
//			ctx, _ := context.WithTimeout(longCtx, 10*60*time.Second) // kill connections after a while until we have live streaming
//			err := sbot.Network.Connect(ctx, row.addr.WrappedAddr())
//			level.Info(log).Log("event", "ssbConnectPeers", "dial", row.addrID, "err", err)
//			connErrs <- &connectResult{
//				row: row,
//				err: err,
//			}
//		}
//		return nil
//	}
//}

//type addrRow struct {
//	addrID uint
//	addr   *multiserver.NetAddress
//}
//
//func queryAddresses(count uint32) ([]*addrRow, error) {
//	var (
//		addresses []*addrRow
//		i         = 0
//		rows      *sql.Rows
//		err       error
//	)
//
//	// keep the query failures in a seperate transaction and commit it after the parse
//	tx, txErr := viewDB.Begin()
//	if txErr != nil {
//		return nil, errors.Wrap(txErr, "queryAddresses: failed to make transaction for failures")
//	}
//
//	rows, err = tx.Query(`SELECT address_id, address from addresses where use = true order by worked_last desc LIMIT ?;`, count)
//	if err != nil {
//		tx.Rollback()
//		return nil, errors.Wrap(err, "queryAddresses: sql query failed")
//	}
//	defer rows.Close()
//
//	for rows.Next() {
//		var (
//			id   uint
//			addr string
//		)
//		err := rows.Scan(&id, &addr)
//		if err != nil {
//			return nil, errors.Wrapf(err, "queryAddresses: sql scan of row %d failed", i)
//		}
//
//		msAddr, err := multiserver.ParseNetAddress([]byte(addr))
//		if err != nil {
//			_, execErr := tx.Exec(`UPDATE addresses set use=false,last_err=? where address_id = ?`, err.Error(), id)
//			if execErr != nil {
//				tx.Rollback()
//				return nil, errors.Wrapf(execErr, "queryAddresses(%d): failed to update parse error row %d", i, id)
//			}
//			continue
//		}
//
//		addresses = append(addresses, &addrRow{
//			addrID: id,
//			addr:   msAddr,
//		})
//
//		i++
//	}
//
//	if err := rows.Err(); err != nil {
//		level.Error(log).Log("where", "qryAddrs", "err", err)
//		tx.Rollback()
//		return nil, err
//	}
//
//	commitErr := tx.Commit()
//	return addresses, errors.Wrap(commitErr, "broken address record update failed")
//}

//export ssbDisconnectAllPeers
func ssbDisconnectAllPeers() bool {
	var err error
	defer logError("ssbDisconnectAllPeers", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	err = service.App.Commands.DisconnectAll.Handle()
	if err != nil {
		err = errors.Wrap(err, "command error")
		return false
	}

	return true
}

//export ssbFeedReplicate
func ssbFeedReplicate(ref string, yes bool) {
	//var err error
	//defer func() {
	//	if err != nil {
	//		level.Error(log).Log("where", "ssbFeedReplicate", "err", err)
	//	}
	//}()

	//fr, err := refs.ParseFeedRef(ref)
	//if err != nil {
	//	err = errors.Wrapf(err, "replicate: invalid feed reference")
	//	return
	//}

	//lock.Lock()
	//defer lock.Unlock()
	//if sbot == nil {
	//	err = ErrNotInitialized
	//	return
	//}

	//if yes {
	//	sbot.Replicate(fr)
	//} else {
	//	sbot.DontReplicate(fr)
	//}
	// todo do we even need this
}

//export ssbFeedBlock
func ssbFeedBlock(ref string, yes bool) {
	//var err error
	//defer func() {
	//	if err != nil {
	//		level.Error(log).Log("where", "ssbFeedBlock", "err", err)
	//	}
	//}()
	//
	//fr, err := refs.ParseFeedRef(ref)
	//if err != nil {
	//	err = errors.Wrapf(err, "block: invalid feed reference")
	//	return
	//}
	//
	//lock.Lock()
	//defer lock.Unlock()
	//if sbot == nil {
	//	err = ErrNotInitialized
	//	return
	//}
	//
	//if yes {
	//	sbot.Block(fr)
	//} else {
	//	sbot.Unblock(fr)
	//}
	// todo
}

//export ssbNullContent
func ssbNullContent(author string, sequence uint64) int {
	return 0
}

//export ssbNullFeed
func ssbNullFeed(ref string) int {
	return 0
}

//export ssbDropIndexData
func ssbDropIndexData() bool {
	return true
}

//export ssbInviteAccept
func ssbInviteAccept(token string) bool {
	return true // todo
	var err error
	defer logError("ssbInviteAccept", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	invite, err := invites.NewInviteFromString(token)
	if err != nil {
		err = errors.Wrap(err, "could not create an invite")
		return false
	}

	cmd := commands.RedeemInvite{
		Invite: invite,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	err = service.App.Commands.RedeemInvite.Handle(ctx, cmd)
	if err != nil {
		err = errors.Wrap(err, "command failed")
		return false
	}

	return true
}

const (
	SsbRoomsAliasRegisterNone              = 0
	SsbRoomsAliasRegisterUnknown           = 1
	SsbRoomsAliasRegisterAliasAlreadyTaken = 2
)

//export ssbRoomsAliasRegister
func ssbRoomsAliasRegister(addressString, aliasString string) C.ssbRoomsAliasRegisterReturn_t {
	var err error
	defer logError("ssbRoomsAliasRegister", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	}

	addr, identity, err := multiserverAddressToAddressAndRef(addressString)
	if err != nil {
		err = errors.Wrap(err, "error parsing the address")
		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	}

	alias, err := aliases.NewAlias(aliasString)
	if err != nil {
		err = errors.Wrap(err, "could not create an alias")
		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	}

	cmd, err := commands.NewRoomsAliasRegister(identity, addr, alias)
	if err != nil {
		err = errors.Wrap(err, "could not create the command")
		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	}

	ctx, cancel := context.WithTimeout(context.TODO(), 30*time.Second)
	defer cancel()

	aliasURL, err := service.App.Commands.RoomsAliasRegister.Handle(ctx, cmd)
	if err != nil {
		err = errors.Wrap(err, "error calling the handler")
		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	}

	// todo alias already registered

	//var ret string
	//err = inviteClient.Async(ctx, &ret, muxrpc.TypeString, muxrpc.Method{"room", "registerAlias"}, params...)
	//if err != nil {
	//	retErr = errors.Wrap(err, "async call failed")
	//	if strings.Contains(err.Error(), "is already taken") {
	//		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterAliasAlreadyTaken}
	//	}
	//	return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	//}
	//

	return C.ssbRoomsAliasRegisterReturn_t{alias: C.CString(aliasURL.String())}
}

//export ssbRoomsAliasRevoke
func ssbRoomsAliasRevoke(addressString, aliasString string) bool {
	var err error
	defer logError("ssbRoomsAliasRevoke", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	addr, identity, err := multiserverAddressToAddressAndRef(addressString)
	if err != nil {
		err = errors.Wrap(err, "error parsing the address")
		return false
	}

	alias, err := aliases.NewAlias(aliasString)
	if err != nil {
		err = errors.Wrap(err, "could not create an alias")
		return false
	}

	cmd, err := commands.NewRoomsAliasRevoke(identity, addr, alias)
	if err != nil {
		err = errors.Wrap(err, "could not create the command")
		return false
	}

	ctx, cancel := context.WithTimeout(context.TODO(), 30*time.Second) // todo
	defer cancel()

	err = service.App.Commands.RoomsAliasRevoke.Handle(ctx, cmd)
	if err != nil {
		err = errors.Wrap(err, "error calling the handler")
		return false
	}

	return true
}

//export ssbRoomsListAliases
func ssbRoomsListAliases(addressString string) *C.char {
	var err error
	defer logError("ssbRoomsListAliases", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	addr, identity, err := multiserverAddressToAddressAndRef(addressString)
	if err != nil {
		err = errors.Wrap(err, "error parsing the address")
		return nil
	}

	query, err := queries.NewRoomsListAliases(identity, addr)
	if err != nil {
		err = errors.Wrap(err, "could not create the command")
		return nil
	}

	ctx, cancel := context.WithTimeout(context.TODO(), 30*time.Second) // todo
	defer cancel()

	aliases, err := service.App.Queries.RoomsListAliases.Handle(ctx, query)
	if err != nil {
		err = errors.Wrap(err, "error calling the handler")
		return nil
	}

	result := make([]string, 0)
	for _, alias := range aliases {
		result = append(result, alias.String())
	}

	j, err := json.Marshal(result)
	if err != nil {
		err = errors.Wrap(err, "error marshaling the result")
		return nil
	}

	return C.CString(string(j))
}

func multiserverAddressToAddressAndRef(multiserverAddress string) (network.Address, refs.Identity, error) {
	netAddress, err := multiserver.ParseNetAddress([]byte(multiserverAddress))
	if err != nil {
		return network.Address{}, refs.Identity{}, errors.Wrap(err, "could not parse the address")
	}

	addr := network.NewAddress(netAddress.Addr.String())

	identity, err := refs.NewIdentity(netAddress.Ref.String())
	if err != nil {
		return network.Address{}, refs.Identity{}, errors.Wrap(err, "error creating an identity ref")
	}

	return addr, identity, nil
}
