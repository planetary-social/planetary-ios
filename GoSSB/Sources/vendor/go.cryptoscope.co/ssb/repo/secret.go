// SPDX-License-Identifier: MIT

package repo

import (
	"io"
	"log"
	"os"
	"path/filepath"

	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
)

func DefaultKeyPair(r Interface) (*ssb.KeyPair, error) {
	secPath := r.GetPath("secret")
	keyPair, err := ssb.LoadKeyPair(secPath)
	if err != nil {
		if !os.IsNotExist(errors.Cause(err)) {
			return nil, errors.Wrap(err, "repo: error opening key pair")
		}
		keyPair, err = ssb.NewKeyPair(nil)
		if err != nil {
			return nil, errors.Wrap(err, "repo: no keypair but couldn't create one either")
		}
		if err := ssb.SaveKeyPair(keyPair, secPath); err != nil {
			return nil, errors.Wrap(err, "repo: error saving new identity file")
		}
		log.Printf("saved identity %s to %s", keyPair.Id.Ref(), secPath)
	}
	return keyPair, nil
}

func NewKeyPair(r Interface, name, algo string) (*ssb.KeyPair, error) {
	return newKeyPair(r, name, algo, nil)
}

func NewKeyPairFromSeed(r Interface, name, algo string, seed io.Reader) (*ssb.KeyPair, error) {
	return newKeyPair(r, name, algo, seed)
}

func newKeyPair(r Interface, name, algo string, seed io.Reader) (*ssb.KeyPair, error) {
	var secPath string
	if name == "-" {
		secPath = r.GetPath("secret")
	} else {
		secPath = r.GetPath("secrets", name)
		err := os.MkdirAll(filepath.Dir(secPath), 0700)
		if err != nil && !os.IsExist(errors.Cause(err)) {
			return nil, err
		}
	}
	if algo != ssb.RefAlgoFeedSSB1 && algo != ssb.RefAlgoFeedGabby { //  enums would be nice
		return nil, errors.Errorf("invalid feed refrence algo")
	}
	if _, err := ssb.LoadKeyPair(secPath); err == nil {
		return nil, errors.Errorf("new key-pair name already taken")
	}
	keyPair, err := ssb.NewKeyPair(seed)
	if err != nil {
		return nil, errors.Wrap(err, "repo: no keypair but couldn't create one either")
	}
	keyPair.Id.Algo = algo
	if err := ssb.SaveKeyPair(keyPair, secPath); err != nil {
		return nil, errors.Wrap(err, "repo: error saving new identity file")
	}
	log.Printf("saved identity %s to %s", keyPair.Id.Ref(), secPath)
	return keyPair, nil
}

func LoadKeyPair(r Interface, name string) (*ssb.KeyPair, error) {
	secPath := r.GetPath("secrets", name)
	keyPair, err := ssb.LoadKeyPair(secPath)
	if err != nil {
		return nil, errors.Wrapf(err, "Load: failed to open %q", secPath)
	}
	return keyPair, nil
}

func AllKeyPairs(r Interface) (map[string]*ssb.KeyPair, error) {
	kps := make(map[string]*ssb.KeyPair)
	err := filepath.Walk(r.GetPath("secrets"), func(path string, info os.FileInfo, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return err
		}
		if info.IsDir() {
			return nil
		}
		if kp, err := ssb.LoadKeyPair(path); err == nil {
			kps[filepath.Base(path)] = kp
			return nil
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return kps, nil
}
