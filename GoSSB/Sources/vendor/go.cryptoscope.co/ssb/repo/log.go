// SPDX-License-Identifier: MIT

package repo

import (
	"github.com/pkg/errors"
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
	return multimsg.NewWrappedLog(log), errors.Wrap(err, "failed to open log")
}
