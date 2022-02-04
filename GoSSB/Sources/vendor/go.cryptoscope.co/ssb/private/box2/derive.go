// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package box2

import (
	"crypto/sha256"
	"fmt"

	"golang.org/x/crypto/hkdf"

	"go.cryptoscope.co/ssb/internal/slp"
)

/*
	Key Derivation scheme

	SharedSecret
	 |
	 +-> SlotKey

	MessageKey (randomly sampled by author)
	 |
	 +-> ReadKey
	 |    |
	 |    +-> HeaderKey
     |    |
     |    +-> BodyKey
	 |
	 +-> ExtensionsKey (TODO)
	      |
		  +-> (TODO: Ratcheting, ...)
*/

func DeriveTo(out, key []byte, infos ...[]byte) error {
	if n := len(out); n != 32 {
		return fmt.Errorf("box2: expected 32b as output argument, got %d", n)
	}
	slp, err := slp.Encode(infos...)
	if err != nil {
		return err
	}
	r := hkdf.Expand(sha256.New, key, slp)
	nout, err := r.Read(out)
	if err != nil {
		return fmt.Errorf("box2: failed to derive key: %w", err)
	}

	if nout != 32 {
		return fmt.Errorf("box2: expected to read 32b into output, got %d", nout)
	}

	return nil
}
