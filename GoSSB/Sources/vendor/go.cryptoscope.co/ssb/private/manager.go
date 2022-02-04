// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package private

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"sort"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/margaret/multilog"
	"go.mindeco.de/encodedTime"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/hkdf"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/internal/extra25519"
	"go.cryptoscope.co/ssb/internal/slp"
	"go.cryptoscope.co/ssb/private/box"
	"go.cryptoscope.co/ssb/private/box2"
	"go.cryptoscope.co/ssb/private/keys"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

// Manager is in charge of storing and retriving keys with the help of keymgr, can de- and encrypt messages and publish them.
type Manager struct {
	receiveLog   margaret.Log
	receiveByRef ssb.Getter

	publog  ssb.Publisher
	tangles multilog.MultiLog

	author ssb.KeyPair

	keymgr *keys.Store
	rand   io.Reader
}

// NewManager creates a new Manager
func NewManager(author ssb.KeyPair, publishLog ssb.Publisher, km *keys.Store, rxlog margaret.Log, getter ssb.Getter, tangles multilog.MultiLog) *Manager {
	return &Manager{
		receiveLog:   rxlog,
		receiveByRef: getter,

		author: author,
		publog: publishLog,

		tangles: tangles,

		keymgr: km,
		rand:   rand.Reader,
	}
}

var (
	dmSalt      = []byte{0x82, 0x84, 0xdc, 0x3, 0x87, 0x86, 0x4d, 0x44, 0x98, 0x1a, 0xa1, 0x4c, 0x66, 0xc4, 0xaf, 0xb7, 0xab, 0xd6, 0xe8, 0xdd, 0x14, 0xad, 0xb9, 0xdf, 0x2d, 0xd8, 0xb9, 0xe, 0x9f, 0xb9, 0xa, 0xb0}
	infoContext = []byte("envelope-ssb-dm-v1/key")
)

// GetOrDeriveKeyFor derives an encryption key for 1:1 private messages with an other feed.
func (mgr *Manager) GetOrDeriveKeyFor(other refs.FeedRef) (keys.Recipients, error) {
	ourID := keys.ID(sortAndConcat(mgr.author.ID().PubKey(), other.PubKey()))
	scheme := keys.SchemeDiffieStyleConvertedED25519

	ks, err := mgr.keymgr.GetKeys(scheme, ourID)
	if err != nil {
		var kerr keys.Error
		if !errors.As(err, &kerr) {
			return nil, fmt.Errorf("ssb/private: key manager internal error: %w", err)
		}
		if kerr.Code != keys.ErrorCodeNoSuchKey {
			return nil, fmt.Errorf("ssb/private: key manager error code: %d", kerr.Code)
		}

		// construct the key that should/can open the header sbox between me and other
		var (
			keyInput      [32]byte // the recipients sbox secret
			otherCurvePub [32]byte // recpt' pub in curve space
			myCurveSec    [32]byte
			myCurvePub    [32]byte
		)

		// for key derivation
		extra25519.PublicKeyToCurve25519(&myCurvePub, mgr.author.ID().PubKey())

		// shared key input
		extra25519.PrivateKeyToCurve25519(&myCurveSec, mgr.author.Secret())
		extra25519.PublicKeyToCurve25519(&otherCurvePub, other.PubKey())
		curve25519.ScalarMult(&keyInput, &myCurveSec, &otherCurvePub)

		// hashed key derivation info preperation
		tfkOther, err := tfk.Encode(other)
		if err != nil {
			return nil, err
		}

		tfkMy, err := tfk.Encode(mgr.author.ID())
		if err != nil {
			return nil, err
		}

		var messageShared = make([]byte, 32)

		var bs = bytesSlice{
			// PSEUDO TFK
			// TODO: add proper type 3 for these curve keys
			append(append([]byte{03, 00}, myCurvePub[:]...), tfkMy...),
			append(append([]byte{03, 00}, otherCurvePub[:]...), tfkOther...),
		}
		sort.Sort(bs)

		slpInfo, err := slp.Encode(nil, infoContext, bs[0], bs[1])
		if err != nil {
			return nil, err
		}
		n, err := hkdf.New(sha256.New, keyInput[:], dmSalt, slpInfo).Read(messageShared)
		if err != nil {
			return nil, err
		}
		if n != 32 {
			return nil, fmt.Errorf("box2: expected 32bytes from hkdf, got %d", n)
		}

		r := keys.Recipient{
			Scheme: scheme,
			Key:    messageShared,
			Metadata: keys.Metadata{
				ForFeed: &other,
			},
		}

		err = mgr.keymgr.SetKey(ourID, r)
		if err != nil {
			return nil, err
		}

		ks = keys.Recipients{r}
	}

	return ks, nil
}

// EncryptBox1 creates box1 ciphertext that is readable by the recipients.
func (mgr *Manager) EncryptBox1(content []byte, rcpts ...refs.FeedRef) ([]byte, error) {
	bxr := box.NewBoxer(mgr.rand)
	ctxt, err := bxr.Encrypt(content, rcpts...)
	if err != nil {
		return nil, fmt.Errorf("error encrypting message (box1): %w", err)
	}
	return ctxt, nil
}

// EncryptBox2 creates box2 ciphertext
func (mgr *Manager) EncryptBox2(content []byte, prev refs.MessageRef, recpts []refs.Ref) ([]byte, error) {

	// first, look up keys
	var (
		allKeys   keys.Recipients
		keyScheme keys.KeyScheme
		keyID     keys.ID
	)

	for _, rcpt := range recpts {
		switch ref := rcpt.(type) {
		case refs.FeedRef:
			keyScheme = keys.SchemeDiffieStyleConvertedED25519
			keyID = keys.ID(sortAndConcat(mgr.author.ID().PubKey(), ref.PubKey()))
			// roll key if not exist?
		case refs.MessageRef:
			// TODO: maybe verify this is a group message?
			keyScheme = keys.SchemeLargeSymmetricGroup
			panic("TODO: fix sortAndConcat")
			// keyID = keys.ID(sortAndConcat(ref.Hash)) // actually just copy
		default:
			return nil, fmt.Errorf("TODO: unhandled recipient reference type: %T", ref)
		}

		if ks, err := mgr.keymgr.GetKeys(keyScheme, keyID); err == nil {
			allKeys = append(allKeys, ks...)
		}

	}

	// then, encrypt message
	bxr := box2.NewBoxer(mgr.rand)
	ctxt, err := bxr.Encrypt(content, mgr.author.ID(), prev, allKeys)
	if err != nil {
		return nil, fmt.Errorf("error encrypting message (box2): %w", err)
	}
	return ctxt, nil
}

// DecryptBox1 does exactly what the name suggests, it returns the cleartext if mgr.author can read it
func (mgr *Manager) DecryptBox1(ctxt []byte) ([]byte, error) {
	// TODO: key managment (single author manager)

	// keyPair := ssb.KeyPair{Id: mgr.author}
	// keyPair.Pair.Secret = make(ed25519.PrivateKey, ed25519.PrivateKeySize)
	// keyPair.Pair.Public = make(ed25519.PublicKey, ed25519.PublicKeySize)

	// // read secret DH key from database
	// keyScheme := keys.SchemeDiffieStyleConvertedED25519
	// keyID := sortAndConcat(mgr.author.ID)

	// ks, err := mgr.keymgr.GetKeys(keyScheme, keyID)
	// if err != nil {
	// 	return nil, errors.Wrapf(err, "could not get key for recipient %s", mgr.author.Ref())
	// }

	// if len(ks) < 1 {
	// 	return nil, fmt.Errorf("no cv25519 secret for feed id %s", mgr.author)
	// }
	// copy(keyPair.Pair.Secret[:], )
	// copy(keyPair.Pair.Public[:], mgr.author.ID)

	bxr := box.NewBoxer(mgr.rand)
	plain, err := bxr.Decrypt(mgr.author, []byte(ctxt))
	return plain, err
}

// DecryptBox2 decrypts box2 messages, using the keys that were previously stored/received.
func (mgr *Manager) DecryptBox2(ctxt []byte, author refs.FeedRef, prev refs.MessageRef) ([]byte, error) {
	// assumes 1:1 pm
	// fetch feed2feed shared key
	keyScheme := keys.SchemeDiffieStyleConvertedED25519
	keyID := sortAndConcat(mgr.author.ID().PubKey(), author.PubKey())
	var allKeys keys.Recipients
	if ks, err := mgr.keymgr.GetKeys(keyScheme, keyID); err == nil {
		allKeys = append(allKeys, ks...)
	}

	// try my groups
	keyScheme = keys.SchemeLargeSymmetricGroup
	keyID = sortAndConcat(mgr.author.ID().PubKey(), mgr.author.ID().PubKey())
	if ks, err := mgr.keymgr.GetKeys(keyScheme, keyID); err == nil {
		allKeys = append(allKeys, ks...)
	}

	if len(allKeys) == 0 {
		return nil, fmt.Errorf("private: do not have a key for box2 message")
	}

	// try decrypt
	bxr := box2.NewBoxer(mgr.rand)
	plain, err := bxr.Decrypt([]byte(ctxt), author, prev, allKeys)
	return plain, err
}

var ErrNotBoxed = fmt.Errorf("private: not a boxed message")

func (mgr *Manager) DecryptMessage(m refs.Message) ([]byte, error) {

	if ctxt, err := mgr.DecryptBox2Message(m); err == nil {
		return ctxt, nil
	}

	if ctxt, err := mgr.DecryptBox1Message(m); err == nil {
		return ctxt, nil
	}

	return nil, ErrNotBoxed
}

func (mgr *Manager) DecryptBox1Message(m refs.Message) ([]byte, error) {
	ciphtext := m.ContentBytes()

	box1Suffix := []byte(".box\"")
	if !bytes.HasSuffix(ciphtext, box1Suffix) {
		return nil, fmt.Errorf("private: not a box1 message")
	}

	b64data := bytes.TrimSuffix(ciphtext[1:], []byte(".box\""))
	boxedData := make([]byte, base64.StdEncoding.DecodedLen(len(ciphtext)-6))
	n, err := base64.StdEncoding.Decode(boxedData, b64data)
	if err != nil {
		return nil, err
	}

	return mgr.DecryptBox1(boxedData[:n])
}

func (mgr *Manager) DecryptBox2Message(m refs.Message) ([]byte, error) {
	ctxt, err := box2.GetCiphertextFromMessage(m)
	if err != nil {
		return nil, err
	}

	return mgr.DecryptBox2(ctxt, m.Author(), *m.Previous())
}

func (mgr *Manager) WrappedUnboxingSink(snk luigi.Sink) luigi.Sink {
	return mfr.SinkMap(snk, func(_ context.Context, v interface{}) (interface{}, error) {
		msg, ok := v.(refs.Message)
		if !ok {
			return nil, fmt.Errorf("failed to find message in empty interface(%T)", v)
		}

		cleartxt, err := mgr.DecryptMessage(msg)
		if err != nil {
			if err == ErrNotBoxed {
				return v, nil
			}
			return nil, fmt.Errorf("unboxing failed: %w", err)
		}

		var rv refs.KeyValueRaw
		rv.Key_ = msg.Key()
		rv.Value.Author = msg.Author()
		rv.Value.Previous = msg.Previous()
		rv.Value.Sequence = msg.Seq()
		rv.Value.Timestamp = encodedTime.NewMillisecs(msg.Claimed().Unix())
		rv.Value.Signature = "reboxed"

		rv.Value.Content = cleartxt

		rv.Value.Meta = make(map[string]interface{})
		rv.Value.Meta["private"] = true

		return rv, nil
	})
}
