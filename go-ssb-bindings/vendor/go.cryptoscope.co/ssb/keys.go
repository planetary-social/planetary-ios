// SPDX-License-Identifier: MIT

package ssb

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/keks/nocomment"
	"github.com/pkg/errors"
	"go.cryptoscope.co/secretstream/secrethandshake"
)

// SecretPerms are the file permissions for holding SSB secrets.
const SecretPerms os.FileMode = 0600

type KeyPair struct {
	Id   *FeedRef
	Pair secrethandshake.EdKeyPair
}

// the format of the .ssb/secret file as defined by the js implementations
type ssbSecret struct {
	Curve   string   `json:"curve"`
	ID      *FeedRef `json:"id"`
	Private string   `json:"private"`
	Public  string   `json:"public"`
}

// IsValidFeedFormat checks if the passed FeedRef is for one of the two supported formats,
// legacy/crapp or GabbyGrove.
func IsValidFeedFormat(r *FeedRef) error {
	if r.Algo != RefAlgoFeedSSB1 && r.Algo != RefAlgoFeedGabby {
		return errors.Errorf("ssb: unsupported feed format:%s", r.Algo)
	}
	return nil
}

// NewKeyPair generates a fresh KeyPair using the passed io.Reader as a seed.
// Passing nil is fine and will use crypto/rand.
func NewKeyPair(r io.Reader) (*KeyPair, error) {

	// generate new keypair
	kp, err := secrethandshake.GenEdKeyPair(r)
	if err != nil {
		return nil, errors.Wrap(err, "ssb: error building key pair")
	}

	keyPair := KeyPair{
		Id:   &FeedRef{ID: kp.Public[:], Algo: "ed25519"},
		Pair: *kp,
	}
	return &keyPair, nil
}

// SaveKeyPair serializes the passed KeyPair to path.
// It errors if path already exists.
func SaveKeyPair(kp *KeyPair, path string) error {
	if err := IsValidFeedFormat(kp.Id); err != nil {
		return err
	}
	if _, err := os.Stat(path); err == nil {
		return errors.Errorf("ssb.SaveKeyPair: key already exists:%q", path)
	}
	err := os.MkdirAll(filepath.Dir(path), 0700)
	if err != nil && !os.IsExist(err) {
		return errors.Wrap(err, "failed to create folder for keypair")
	}
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_TRUNC, SecretPerms)
	if err != nil {
		return errors.Wrap(err, "ssb.SaveKeyPair: failed to create file")
	}

	if err := EncodeKeyPairAsJSON(kp, f); err != nil {
		return err
	}

	return errors.Wrap(f.Close(), "ssb.SaveKeyPair: failed to close file")
}

// EncodeKeyPairAsJSON serializes the passed Keypair into the writer w
func EncodeKeyPairAsJSON(kp *KeyPair, w io.Writer) error {
	var sec = ssbSecret{
		Curve:   "ed25519",
		ID:      kp.Id,
		Private: base64.StdEncoding.EncodeToString(kp.Pair.Secret[:]) + ".ed25519",
		Public:  base64.StdEncoding.EncodeToString(kp.Pair.Public[:]) + ".ed25519",
	}
	err := json.NewEncoder(w).Encode(sec)
	return errors.Wrap(err, "ssb.EncodeKeyPairAsJSON: encoding failed")
}

// LoadKeyPair opens fname, ignores any line starting with # and passes it ParseKeyPair
func LoadKeyPair(fname string) (*KeyPair, error) {
	f, err := os.Open(fname)
	if err != nil {
		return nil, errors.Wrapf(err, "ssb.LoadKeyPair: could not open key file %s", fname)
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return nil, errors.Wrapf(err, "ssb.LoadKeyPair: could not stat key file %s", fname)
	}
	if perms := info.Mode().Perm(); perms != SecretPerms {
		return nil, fmt.Errorf("ssb.LoadKeyPair: expected key file permissions %s, but got %s", SecretPerms, perms)
	}

	return ParseKeyPair(nocomment.NewReader(f))
}

// ParseKeyPair json decodes an object from the reader.
// It expects std base64 encoded data under the `private` and `public` fields.
func ParseKeyPair(r io.Reader) (*KeyPair, error) {
	var s ssbSecret
	if err := json.NewDecoder(r).Decode(&s); err != nil {
		return nil, errors.Wrapf(err, "ssb.Parse: JSON decoding failed")
	}

	if err := IsValidFeedFormat(s.ID); err != nil {
		return nil, err
	}

	public, err := base64.StdEncoding.DecodeString(strings.TrimSuffix(s.Public, ".ed25519"))
	if err != nil {
		return nil, errors.Wrapf(err, "ssb.Parse: base64 decode of public part failed")
	}

	private, err := base64.StdEncoding.DecodeString(strings.TrimSuffix(s.Private, ".ed25519"))
	if err != nil {
		return nil, errors.Wrapf(err, "ssb.Parse: base64 decode of private part failed")
	}

	pair, err := secrethandshake.NewKeyPair(public, private)
	if err != nil {
		return nil, errors.Wrapf(err, "ssb.Parse: base64 decode of private part failed")
	}

	ssbkp := KeyPair{
		Id:   s.ID,
		Pair: *pair,
	}
	return &ssbkp, errors.Wrap(err, "ssb.Parse: broken keypair?")
}
