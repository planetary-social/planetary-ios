// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package neterr

import (
	"errors"
	"net"
	"os"
	"syscall"
)

func IsConnBrokenErr(err error) bool {
	netErr := new(net.OpError)
	if errors.As(err, &netErr) {
		var sysCallErr = new(os.SyscallError)
		if errors.As(netErr.Err, &sysCallErr) {
			action := sysCallErr.Unwrap()
			if action == syscall.ECONNRESET || action == syscall.EPIPE {
				return true
			}
		}
		if netErr.Err.Error() == "use of closed network connection" {
			return true
		}
	}
	return false
}
