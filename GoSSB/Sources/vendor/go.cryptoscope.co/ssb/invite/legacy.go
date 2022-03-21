// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package invite contains functions for parsing invite codes and dialing a pub as a guest to redeem a token.
// The muxrpc handlers and storage are found in plugins/legacyinvite.
package invite

import (
	"bytes"
	"context"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/client"
	refs "go.mindeco.de/ssb-refs"
)

// Redeem takes an invite token and a long term key.
// It uses the information in the token to build a guest-client connection
// and place an 'invite.use' rpc call with it's longTerm key.
// If the peer responds with a message it returns nil
func Redeem(ctx context.Context, tok Token, longTerm refs.FeedRef) error {
	inviteKeyPair, err := ssb.NewKeyPair(bytes.NewReader(tok.Seed[:]), refs.RefAlgoFeedSSB1)
	if err != nil {
		return fmt.Errorf("invite: couldn't make keypair from seed: %w", err)
	}

	// now use the invite
	inviteClient, err := client.NewTCP(inviteKeyPair, tok.Address, client.WithContext(ctx))
	if err != nil {
		return fmt.Errorf("invite: failed to establish guest-client connection: %w", err)
	}

	var ret refs.KeyValueRaw
	var param = struct {
		Feed string `json:"feed"`
	}{longTerm.String()}

	err = inviteClient.Async(ctx, &ret, muxrpc.TypeJSON, muxrpc.Method{"invite", "use"}, param)
	if err != nil {
		return fmt.Errorf("invite: invalid token: %w", err)
	}

	inviteClient.Close()
	return nil
}
