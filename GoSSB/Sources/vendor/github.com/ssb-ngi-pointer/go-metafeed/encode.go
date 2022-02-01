// SPDX-License-Identifier: MIT

package metafeed

import (
	"fmt"
	"math"
	"time"

	"github.com/zeebo/bencode"
	"golang.org/x/crypto/ed25519"

	"github.com/ssb-ngi-pointer/go-metafeed/internal/sign"
	refs "go.mindeco.de/ssb-refs"
)

// NewEncoder creates an encoding facility which uses the passed author to sign new messages
func NewEncoder(author ed25519.PrivateKey) *Encoder {
	pe := &Encoder{}
	pe.privKey = author
	return pe
}

// Encoder exposes two control options for timestamps and the hmac key and the Encode() function which creates new signed messages.
type Encoder struct {
	privKey ed25519.PrivateKey

	hmacSecret   *[32]byte
	setTimestamp bool
}

// WithNowTimestamps controls wether timestamps should be used to create new messages
func (e *Encoder) WithNowTimestamps(yes bool) {
	e.setTimestamp = yes
}

// WithHMAC update the HMAC signing secret
func (e *Encoder) WithHMAC(in []byte) error {
	var k [32]byte
	n := copy(k[:], in)
	if n != 32 {
		return fmt.Errorf("hmac key to short: %d", n)
	}
	e.hmacSecret = &k
	return nil
}

// for testable timestamps, so that now can be reset in the tests
var now = time.Now

// SetNow can be used to create arbitrary timestamps on a message.
// Mostly used for testing.
func SetNow(fn func() time.Time) {
	now = fn
}

// Encode uses the passed sequence and previous message reference to create a signed messages over the passed value.
func (e *Encoder) Encode(sequence int32, prev refs.MessageRef, val interface{}) (*Message, refs.MessageRef, error) {
	var (
		err  error
		next Payload

		pubKeyBytes = []byte(e.privKey.Public().(ed25519.PublicKey))
	)

	next.Author, err = refs.NewFeedRefFromBytes(pubKeyBytes, refs.RefAlgoFeedBendyButt)
	if err != nil {
		return nil, refs.MessageRef{}, err
	}

	if sequence > math.MaxInt32 {
		return nil, refs.MessageRef{}, fmt.Errorf("metafeed: sequence limit reached. can't publish more then %d entries", math.MaxInt32)
	}
	next.Sequence = int(sequence)

	if sequence > 1 {
		if prevAlgo := prev.Algo(); prevAlgo != refs.RefAlgoMessageBendyButt {
			return nil, refs.MessageRef{}, fmt.Errorf("metafeed: previous is not a bb-msg reference but %s", prevAlgo)
		}
		next.Previous = &prev
	}

	if e.setTimestamp {
		next.Timestamp = now()
	}

	next.Content, err = bencode.EncodeBytes(val)
	if err != nil {
		return nil, refs.MessageRef{}, fmt.Errorf("metafeed: failed to encode value: %w", err)
	}

	nextEncoded, err := next.MarshalBencode()
	if err != nil {
		return nil, refs.MessageRef{}, fmt.Errorf("metafeed: failed to encode next entry: %w", err)
	}

	var msg Message
	msg.Data = nextEncoded
	msg.Signature = sign.Create(nextEncoded, e.privKey, e.hmacSecret)

	return &msg, msg.Key(), nil
}

func refFromPubKey(pk ed25519.PublicKey) (refs.FeedRef, error) {
	if len(pk) != ed25519.PublicKeySize {
		return refs.FeedRef{}, fmt.Errorf("invalid public key")
	}
	return refs.NewFeedRefFromBytes(pk, refs.RefAlgoFeedBendyButt)
}
