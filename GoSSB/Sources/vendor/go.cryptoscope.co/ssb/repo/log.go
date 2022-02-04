// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package repo

import (
	"fmt"

	"go.cryptoscope.co/margaret/offset2"
	"go.cryptoscope.co/ssb/message/multimsg"
)

func OpenLog(r Interface, path ...string) (multimsg.AlterableLog, error) {
	// prefix path with "logs" if path is not empty, otherwise use "log"
	path = append([]string{"log"}, path...)
	if len(path) > 1 {
		path[0] = "logs"
	}

	// TODO use proper log message type here
	log, err := offset2.Open(r.GetPath(path...), multimsg.MargaretCodec{})
	if err != nil {
		return nil, fmt.Errorf("failed to open log: %w", err)
	}
	return multimsg.NewWrappedLog(log), nil
}
