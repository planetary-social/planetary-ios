// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// +build windows

package ssb

import (
	"os"
)

// SecretPerms are the file permissions for holding SSB secrets.
// Windows has it's own permission system apart from UNIX (owner, group, others)
var SecretPerms = os.FileMode(0666)
