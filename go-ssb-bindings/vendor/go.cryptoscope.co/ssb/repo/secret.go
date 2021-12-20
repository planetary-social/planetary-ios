// SPDX-License-Identifier: MIT

package repo

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

func DefaultKeyPair(r Interface, algo refs.RefAlgo) (ssb.KeyPair, error) {
	secPath := r.GetPath("secret")
	keyPair, err := ssb.LoadKeyPair(secPath)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, fmt.Errorf("repo: error opening key pair: %w", err)
		}
		keyPair, err = ssb.NewKeyPair(nil, algo)
		if err != nil {
			return nil, fmt.Errorf("repo: no keypair but couldn't create one either: %w", err)
		}
		if err := ssb.SaveKeyPair(keyPair, secPath); err != nil {
			return nil, fmt.Errorf("repo: error saving new identity file: %w", err)
		}
		log.Printf("saved identity %s to %s", keyPair.ID().Ref(), secPath)
	}
	return keyPair, nil
}

func NewKeyPair(r Interface, name string, algo refs.RefAlgo) (ssb.KeyPair, error) {
	return newKeyPair(r, name, algo, nil)
}

func NewKeyPairFromSeed(r Interface, name string, algo refs.RefAlgo, seed io.Reader) (ssb.KeyPair, error) {
	return newKeyPair(r, name, algo, seed)
}

func newKeyPair(r Interface, name string, algo refs.RefAlgo, seed io.Reader) (ssb.KeyPair, error) {
	var secPath string
	if name == "-" {
		secPath = r.GetPath("secret")
	} else {
		secPath = r.GetPath("secrets", name)
		err := os.MkdirAll(filepath.Dir(secPath), 0700)
		if err != nil && !os.IsExist(err) {
			return nil, err
		}
	}
	// TODO: move to refs pkg
	if algo != refs.RefAlgoFeedSSB1 &&
		algo != refs.RefAlgoFeedGabby &&
		algo != refs.RefAlgoFeedBendyButt { //  enums would be nice
		return nil, fmt.Errorf("invalid feed refrence algo")
	}
	if _, err := ssb.LoadKeyPair(secPath); err == nil {
		return nil, fmt.Errorf("new key-pair name already taken")
	}

	keyPair, err := ssb.NewKeyPair(seed, algo)
	if err != nil {
		return nil, fmt.Errorf("repo: no keypair but couldn't create one either: %w", err)
	}

	if err := ssb.SaveKeyPair(keyPair, secPath); err != nil {
		return nil, fmt.Errorf("repo: error saving new identity file: %w", err)
	}
	log.Printf("saved identity %s to %s", keyPair.ID().Ref(), secPath)
	return keyPair, nil
}

func LoadKeyPair(r Interface, name string) (ssb.KeyPair, error) {
	secPath := r.GetPath("secrets", name)
	keyPair, err := ssb.LoadKeyPair(secPath)
	if err != nil {
		return nil, fmt.Errorf("Load: failed to open %q: %w", secPath, err)
	}
	return keyPair, nil
}

func AllKeyPairs(r Interface) (map[string]ssb.KeyPair, error) {
	kps := make(map[string]ssb.KeyPair)
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
