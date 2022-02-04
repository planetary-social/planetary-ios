// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// +build !darwin
// +build !windows

package ssb

import "os"

// SecretPerms are the file permissions for holding SSB secrets.
// We expect the file to only be accessable by the owner.
var SecretPerms = os.FileMode(0400)
