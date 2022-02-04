// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package ssb

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	"github.com/ssb-ngi-pointer/go-metafeed/metakeys"
	"go.cryptoscope.co/nocomment"
	"go.cryptoscope.co/secretstream/secrethandshake"
	"golang.org/x/crypto/ed25519"

	refs "go.mindeco.de/ssb-refs"
)

type KeyPair interface {
	ID() refs.FeedRef
	Secret() ed25519.PrivateKey
}

func EdKeyPair(kp KeyPair) secrethandshake.EdKeyPair {
	return secrethandshake.EdKeyPair{
		Public: kp.ID().PubKey(),
		Secret: kp.Secret(),
	}
}

type LegacyKeyPair struct {
	Feed refs.FeedRef
	Pair secrethandshake.EdKeyPair
}

func (lkp LegacyKeyPair) ID() refs.FeedRef {
	return lkp.Feed
}

func (lkp LegacyKeyPair) Secret() ed25519.PrivateKey {
	return lkp.Pair.Secret
}

// the format of the .ssb/secret file as defined by the js implementations
type ssbSecret struct {
	Curve   string       `json:"curve"`
	ID      refs.FeedRef `json:"id"`
	Private string       `json:"private"`
	Public  string       `json:"public"`
}

// IsValidFeedFormat checks if the passed FeedRef is for one of the two supported formats,
// legacy/crapp or GabbyGrove.
func IsValidFeedFormat(r refs.FeedRef) error {
	ra := r.Algo()
	if ra != refs.RefAlgoFeedSSB1 && ra != refs.RefAlgoFeedGabby && ra != refs.RefAlgoFeedBendyButt {
		return fmt.Errorf("ssb: unsupported feed format: %s", r.Algo())
	}
	return nil
}

// NewKeyPair generates a fresh KeyPair using the passed io.Reader as a seed.
// Passing nil is fine and will use crypto/rand.
func NewKeyPair(r io.Reader, algo refs.RefAlgo) (KeyPair, error) {
	if algo == "" {
		return nil, fmt.Errorf("ssb: empty feed format algo for keypair")
	}

	var keyPair KeyPair
	if algo == refs.RefAlgoFeedBendyButt {
		seed, err := metakeys.GenerateSeed()
		if err != nil {
			return nil, err
		}

		keyPair, err = metakeys.DeriveFromSeed(seed, "go-ssb-metafeed", refs.RefAlgoFeedBendyButt)
		if err != nil {
			return nil, err
		}
	} else {
		// generate new keypair
		kp, err := secrethandshake.GenEdKeyPair(r)
		if err != nil {
			return nil, fmt.Errorf("ssb: error building key pair: %w", err)
		}

		lkp := LegacyKeyPair{
			Pair: *kp,
		}

		lkp.Feed, err = refs.NewFeedRefFromBytes(kp.Public[:], algo)
		if err != nil {
			return nil, err
		}
		keyPair = lkp
	}

	return keyPair, nil
}

// SaveKeyPair serializes the passed KeyPair to path.
// It errors if path already exists.
func SaveKeyPair(kp KeyPair, path string) error {
	if err := IsValidFeedFormat(kp.ID()); err != nil {
		return err
	}

	if _, err := os.Stat(path); err == nil {
		return fmt.Errorf("ssb.SaveKeyPair: key already exists:%q", path)
	}

	err := os.MkdirAll(filepath.Dir(path), 0700)
	if err != nil && !os.IsExist(err) {
		return fmt.Errorf("failed to create folder for keypair: %w", err)
	}

	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_TRUNC, SecretPerms)
	if err != nil {
		return fmt.Errorf("ssb.SaveKeyPair: failed to create file: %w", err)
	}

	if enc, ok := kp.(json.Marshaler); ok {
		data, err := enc.MarshalJSON()
		if err != nil {
			return err
		}

		n, err := f.Write(data)
		if err != nil {
			return err
		}

		if n != len(data) {
			return fmt.Errorf("ssb.SaveKeyPair: failed to save all encoded bytes of the keypair")
		}
	} else {
		if err := EncodeKeyPairAsJSON(kp, f); err != nil {
			return err
		}
	}

	if err := f.Close(); err != nil {
		return fmt.Errorf("ssb.SaveKeyPair: failed to close file: %w", err)
	}

	return nil
}

// EncodeKeyPairAsJSON serializes the passed Keypair into the writer w
func EncodeKeyPairAsJSON(kp KeyPair, w io.Writer) error {
	var sec = ssbSecret{
		Curve:   "ed25519",
		ID:      kp.ID(),
		Private: base64.StdEncoding.EncodeToString(kp.Secret()) + ".ed25519",
		Public:  base64.StdEncoding.EncodeToString(kp.ID().PubKey()) + ".ed25519",
	}
	err := json.NewEncoder(w).Encode(sec)
	if err != nil {
		return fmt.Errorf("ssb.EncodeKeyPairAsJSON: encoding failed: %w", err)
	}
	return nil
}

// LoadKeyPair opens fname, ignores any line starting with # and passes it ParseKeyPair
func LoadKeyPair(fname string) (KeyPair, error) {
	f, err := os.Open(fname)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, err
		}

		return nil, fmt.Errorf("ssb.LoadKeyPair: could not open key file %s: %w", fname, err)
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return nil, fmt.Errorf("ssb.LoadKeyPair: could not stat key file %s: %w", fname, err)
	}

	// secret key permissions are not what they should be
	if perms := info.Mode().Perm(); perms != SecretPerms {
		// try to correct permissions on secret
		err = os.Chmod(fname, SecretPerms)
		if err != nil {
			return nil, fmt.Errorf("ssb.LoadKeyPair: failed to correct permissions from %s to %s (%w)", perms, SecretPerms, err)
		}
	}

	kp, err := ParseKeyPair(nocomment.NewReader(f))
	if err == nil {
		return kp, nil
	}

	// roll back and read again
	_, err = f.Seek(0, io.SeekStart)
	if err != nil {
		return nil, err
	}

	keyData, err := ioutil.ReadAll(f)
	if err != nil {
		return nil, err
	}

	var mkp metakeys.KeyPair
	err = mkp.UnmarshalJSON(keyData)
	if err != nil {
		return nil, err
	}

	return mkp, nil

}

// ParseKeyPair json decodes an object from the reader.
// It expects std base64 encoded data under the `private` and `public` fields.
func ParseKeyPair(r io.Reader) (KeyPair, error) {
	var s ssbSecret
	if err := json.NewDecoder(r).Decode(&s); err != nil {
		return nil, fmt.Errorf("ssb.Parse: JSON decoding failed: %w", err)
	}

	if err := IsValidFeedFormat(s.ID); err != nil {
		return nil, err
	}

	public, err := base64.StdEncoding.DecodeString(strings.TrimSuffix(s.Public, ".ed25519"))
	if err != nil {
		return nil, fmt.Errorf("ssb.Parse: base64 decode of public part failed: %w", err)
	}

	private, err := base64.StdEncoding.DecodeString(strings.TrimSuffix(s.Private, ".ed25519"))
	if err != nil {
		return nil, fmt.Errorf("ssb.Parse: base64 decode of private part failed: %w", err)
	}

	pair, err := secrethandshake.NewKeyPair(public, private)
	if err != nil {
		return nil, fmt.Errorf("ssb.Parse: base64 decode of private part failed: %w", err)
	}

	ssbkp := LegacyKeyPair{
		Feed: s.ID,
		Pair: *pair,
	}
	return ssbkp, nil
}
