// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package box2

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	stderr "errors"
	"fmt"
	"io"

	"golang.org/x/crypto/nacl/secretbox"

	"go.cryptoscope.co/ssb/private/keys"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

const (
	KeySize = 256 / 8

	MaxSlots = 32
)

var (
	zero24  [24]byte
	zeroKey [KeySize]byte
)

type Message struct {
	Raw []byte

	HeaderBox   []byte
	AfterHeader []byte

	OffBody  int
	RawSlots []byte
	BodyBox  []byte
}

func NewBoxer(rand io.Reader) *Boxer {
	return &Boxer{rand: rand}
}

type Boxer struct {
	rand io.Reader
}

type makeHKDFContextList func(...[]byte) [][]byte

func makeInfo(author refs.FeedRef, prev refs.MessageRef) (makeHKDFContextList, error) {
	tfkFeed, err := tfk.FeedFromRef(author)
	if err != nil {
		return nil, fmt.Errorf("failed to make tfk for author: %w", err)
	}
	feedBytes, err := tfkFeed.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("failed to encode tfk for author: %w", err)
	}

	tfkMsg, err := tfk.MessageFromRef(prev)
	if err != nil {
		return nil, fmt.Errorf("failed to make tfk for previous message: %w", err)
	}
	msgBytes, err := tfkMsg.MarshalBinary()
	if err != nil {
		return nil, fmt.Errorf("failed to encode tfk for previous message: %w", err)
	}

	return func(infos ...[]byte) [][]byte {
		out := make([][]byte, len(infos)+3)
		out[0] = []byte("envelope")
		out[1] = feedBytes
		out[2] = msgBytes
		copy(out[3:], infos)
		return out
	}, nil
}

// API and processing errors
var (
	ErrTooManyRecipients = stderr.New("box2: too many recipients")
	ErrCouldNotDecrypt   = stderr.New("box2: could not decrypt")
	ErrInvalid           = stderr.New("box2: message is invalid")
	ErrEmptyPlaintext    = stderr.New("box2: won't encrypt empty plaintext")
	ErrInvalidOffset     = stderr.New("box2: precalculated body offset does not match real body offset")
)

// Encrypt takes a buffer to write into (out), the plaintext to encrypt, the (author) of the message, her (prev)ious message hash and a list of recipients (recpts).
// If out is too small to hold the full message, additonal allocations will be made. The ciphertext is returned as the first return value.
func (bxr *Boxer) Encrypt(plain []byte, author refs.FeedRef, prev refs.MessageRef, recpts []keys.Recipient) ([]byte, error) {
	if len(plain) == 0 {
		return nil, ErrEmptyPlaintext
	}

	if len(recpts) > MaxSlots {
		return nil, ErrTooManyRecipients
	}

	var (
		msgKey    [KeySize]byte
		readKey   [KeySize]byte
		bodyKey   [KeySize]byte
		headerKey [KeySize]byte
		slotKey   [KeySize]byte

		// header length + len(rceps) * slot length
		bodyOff uint16 = 32 + uint16(len(recpts))*32

		// header plaintext
		headerPlain [16]byte
	)

	_, err := bxr.rand.Read(msgKey[:])
	if err != nil {
		return nil, fmt.Errorf("box2/encrypt: error reading random data: %w", err)
	}

	info, err := makeInfo(author, prev)
	if err != nil {
		return nil, fmt.Errorf("box2/encrypt: error constructing keying information: %w", err)
	}

	err = DeriveTo(readKey[:], msgKey[:], info([]byte("read_key"))...)
	if err != nil {
		return nil, err
	}

	// build header plaintext
	binary.LittleEndian.PutUint16(headerPlain[:], bodyOff)

	// append header ciphertext
	err = DeriveTo(headerKey[:], readKey[:], info([]byte("header_key"))...)
	if err != nil {
		return nil, fmt.Errorf("box2/encrypt: header key derivation vailed: %w", err)
	}

	out := secretbox.Seal(nil, headerPlain[:], &zero24, &headerKey)
	clear(headerKey[:])

	// append slots
	for _, bk := range recpts {
		err = DeriveTo(slotKey[:], bk.Key, info([]byte("slot_key"), []byte(bk.Scheme))...)
		if err != nil {
			return nil, fmt.Errorf("box2/encrypt: slot key derivation vailed: %w", err)
		}

		out = append(out, make([]byte, KeySize)...)
		for i := range slotKey {
			out[len(out)-KeySize+i] = slotKey[i] ^ msgKey[i]
		}
	}
	clear(msgKey[:])

	// let's not spread broken messages
	if len(out) != int(bodyOff) {
		return nil, ErrInvalidOffset
	}

	// append encrypted body
	err = DeriveTo(bodyKey[:], readKey[:], info([]byte("body_key"))...)
	if err != nil {
		return nil, fmt.Errorf("box2/encrypt: body key derivation vailed: %w", err)
	}

	out = secretbox.Seal(out, plain, &zero24, &bodyKey)
	clear(bodyKey[:])
	clear(readKey[:])

	return out, nil
}

func deriveMessageKey(author refs.FeedRef, prev refs.MessageRef, candidates []keys.Recipient) ([][KeySize]byte, makeHKDFContextList, error) {
	var slotKeys = make([][KeySize]byte, len(candidates))

	info, err := makeInfo(author, prev)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to make info: %w", err)
	}

	// derive slot keys
	for i, candidate := range candidates {
		err = DeriveTo(slotKeys[i][:], candidate.Key, info([]byte("slot_key"), []byte(candidate.Scheme))...)
		if err != nil {
			return nil, nil, fmt.Errorf("derivation for canidate:%d (%s) failed: %w", i, candidate, err)
		}

	}

	return slotKeys, info, nil
}

func (bxr *Boxer) GetReadKey(ctxt []byte, author refs.FeedRef, prev refs.MessageRef, candidates []keys.Recipient) ([]byte, error) {
	_, readKey, _, err := bxr.getReadKey(ctxt, author, prev, candidates)
	if err != nil {
		return nil, err
	}
	return readKey[:], nil
}

func (bxr *Boxer) getReadKey(ctxt []byte, author refs.FeedRef, prev refs.MessageRef, candidates []keys.Recipient) (
	[]byte,
	[KeySize]byte,
	makeHKDFContextList,
	error) {
	slotKeys, info, err := deriveMessageKey(author, prev, candidates)
	if err != nil {
		err = fmt.Errorf("error constructing keying information: %w", err)
		return nil, [KeySize]byte{}, nil, err
	}
	var (
		hdr               = make([]byte, 16)
		msgKey, headerKey [KeySize]byte
		readKey           [KeySize]byte
		slot              []byte
		ok                bool
		i, j, k           int

		headerbox   = ctxt[:32]
		afterHeader = ctxt[32:]
	)

	// find correct slot key and decrypt header
OUTER:
	for i = 0; (i+1)*KeySize < len(afterHeader) && i < MaxSlots; i++ {
		slot = afterHeader[i*KeySize : (i+1)*KeySize]

		for j = 0; j < len(slotKeys); j++ {
			// xor slotKey and slot to get the msgKey
			for k = range slotKeys[j] {
				msgKey[k] = slotKeys[j][k] ^ slot[k]
			}

			err = DeriveTo(readKey[:], msgKey[:], info([]byte("read_key"))...)
			if err != nil {
				return nil, [KeySize]byte{}, nil, err
			}

			err = DeriveTo(headerKey[:], readKey[:], info([]byte("header_key"))...)
			if err != nil {
				return nil, [KeySize]byte{}, nil, err
			}

			hdr, ok = secretbox.Open(hdr[:0], headerbox, &zero24, &headerKey)
			if ok {
				break OUTER
			}
		}
	}
	if !ok {
		err = ErrCouldNotDecrypt
		return nil, [KeySize]byte{}, nil, err
	}

	return hdr, readKey, info, nil
}

// Decrypt takes the ciphertext, it's auther and the previous hash of the message and some canddiates to try to decrypt with.
// It returns the decrypted cleartext or an error.
func (bxr *Boxer) Decrypt(ctxt []byte, author refs.FeedRef, prev refs.MessageRef, candidates []keys.Recipient) ([]byte, error) {
	// TODO
	hdr, readKey, info, err := bxr.getReadKey(ctxt, author, prev, candidates)
	if err != nil {
		return nil, err
	}

	var (
		bodyOffset = int(binary.LittleEndian.Uint16(hdr))
		plain      = make([]byte, 0, len(ctxt)-bodyOffset-secretbox.Overhead)
		bodyKey    [KeySize]byte
	)

	// decrypt body
	err = DeriveTo(bodyKey[:], readKey[:], info([]byte("body_key"))...)
	if err != nil {
		return nil, err
	}
	plain, ok := secretbox.Open(plain, ctxt[bodyOffset:], &zero24, &bodyKey)
	if !ok {
		return nil, ErrInvalid
	}

	return plain, nil
}

// utils
// func (mgr *Manager)

var box2Suffix = []byte(".box2\"")

func GetCiphertextFromMessage(m refs.Message) ([]byte, error) {
	content := m.ContentBytes()

	if !bytes.HasSuffix(content, box2Suffix) {
		return nil, fmt.Errorf("message does not have .box2 suffix")
	}

	n := base64.StdEncoding.DecodedLen(len(content))
	ctxt := make([]byte, n)
	decn, err := base64.StdEncoding.Decode(ctxt, bytes.TrimSuffix(content, box2Suffix)[1:])
	if err != nil {
		return nil, err
	}
	return ctxt[:decn], nil
}

func clear(buf []byte) {
	for i := range buf {
		buf[i] = 0
	}
}
