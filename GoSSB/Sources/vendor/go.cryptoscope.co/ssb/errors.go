// SPDX-License-Identifier: MIT

package ssb

import (
	"encoding/json"
	"fmt"

	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
)

var ErrShuttingDown = errors.Errorf("ssb: shutting down now") // this is fine

type ErrOutOfReach struct {
	Dist int
	Max  int
}

func (e ErrOutOfReach) Error() string {
	return fmt.Sprintf("ssb/graph: peer not in reach. d:%d, max:%d", e.Dist, e.Max)
}

func IsMessageUnusable(err error) bool {
	cause := errors.Cause(err)
	_, is := cause.(ErrWrongType)
	if is {
		return true
	}
	_, is = cause.(ErrMalfromedMsg)
	if is {
		return true
	}
	_, is = cause.(*json.SyntaxError)
	return is
}

type ErrMalfromedMsg struct {
	reason string
	m      map[string]interface{}
}

func (emm ErrMalfromedMsg) Error() string {
	s := "ErrMalfromedMsg: " + emm.reason
	if emm.m != nil {
		s += fmt.Sprintf(" %+v", emm.m)
	}
	return s
}

type ErrWrongType struct {
	has, want string
}

func (ewt ErrWrongType) Error() string {
	return fmt.Sprintf("ErrWrongType: want: %s has: %s", ewt.want, ewt.has)
}

var ErrUnuspportedFormat = errors.Errorf("ssb: unsupported format")

// ErrWrongSequence is returned if there is a glitch on the current
// sequence number on the feed between in the offsetlog and the logical entry on the feed
type ErrWrongSequence struct {
	Ref             *FeedRef
	Logical, Stored margaret.Seq
}

func (e ErrWrongSequence) Error() string {
	return fmt.Sprintf("ssb/consistency error: message sequence missmatch for feed %s Stored:%d Logical:%d",
		e.Ref.Ref(),
		e.Stored.Seq(),
		e.Logical.Seq())
}
