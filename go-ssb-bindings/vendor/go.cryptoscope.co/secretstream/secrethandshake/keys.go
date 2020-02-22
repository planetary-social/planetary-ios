// SPDX-License-Identifier: MIT

package secrethandshake

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"strings"
)

func LoadSSBKeyPair(fname string) (*EdKeyPair, error) {
	f, err := os.Open(fname)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var sbotKey struct {
		Curve   string `json:"curve"`
		ID      string `json:"id"`
		Private string `json:"private"`
		Public  string `json:"public"`
	}

	if err := json.NewDecoder(f).Decode(&sbotKey); err != nil {
		return nil, ErrEncoding{what: "json key data", cause: err}
	}

	public, err := base64.StdEncoding.DecodeString(strings.TrimSuffix(sbotKey.Public, ".ed25519"))
	if err != nil {

		return nil, ErrEncoding{what: "base64 of public key", cause: err}
	}

	private, err := base64.StdEncoding.DecodeString(strings.TrimSuffix(sbotKey.Private, ".ed25519"))
	if err != nil {
		return nil, ErrEncoding{what: "base64 of private key", cause: err}
	}

	var kp EdKeyPair
	copy(kp.Public[:], public)
	copy(kp.Secret[:], private)
	return &kp, nil
}
