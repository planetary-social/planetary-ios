// +build darwin

package ssb

import "os"

// SecretPerms are the file permissions for holding SSB secrets.
// OSX installation expects the file to be read only by the owner.
var SecretPerms = os.FileMode(0400)
