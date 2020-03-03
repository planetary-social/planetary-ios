package invite

import (
	"bytes"
	"context"
	"log"

	"github.com/pkg/errors"
	"go.cryptoscope.co/muxrpc"
	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/client"
)

// Redeem takes an invite token and a long term key.
// It uses the information in the token to build a guest-client connection
// and place an 'invite.use' rpc call with it's longTerm key.
// If the peer responds with a message it returns nil
func Redeem(ctx context.Context, tok Token, longTerm *ssb.FeedRef) error {
	inviteKeyPair, err := ssb.NewKeyPair(bytes.NewReader(tok.Seed[:]))
	if err != nil {
		return errors.Wrap(err, "invite: couldn't make keypair from seed")
	}

	// now use the invite
	inviteClient, err := client.NewTCP(inviteKeyPair, tok.Address, client.WithContext(ctx))
	if err != nil {
		return errors.Wrap(err, "invite: failed to establish guest-client connection")
	}

	var ret ssb.KeyValueRaw
	var param = struct {
		Feed string `json:"feed"`
	}{longTerm.Ref()}

	inviteReply, err := inviteClient.Async(ctx, ret, muxrpc.Method{"invite", "use"}, param)
	if err != nil {
		return errors.Wrap(err, "invite: invalid token")
	}
	msg, ok := inviteReply.(ssb.Message)
	if !ok {
		return errors.Errorf("invite: reply was not a message")
	}
	log.Println("invite redeemed. Peer replied with msg", msg.Key().Ref())

	return inviteClient.Close()
}
