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

//export ssbInviteAccept
func ssbInviteAccept(token string) bool {
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
		if errors.Is(err, commands.ErrRoomAliasAlreadyTaken) {
			return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterAliasAlreadyTaken}
		}
		err = errors.Wrap(err, "error calling the handler")
		return C.ssbRoomsAliasRegisterReturn_t{err: SsbRoomsAliasRegisterUnknown}
	}

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
