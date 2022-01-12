// SPDX-License-Identifier: MIT

package margaret // import "go.cryptoscope.co/margaret"

const (
	// SeqEmpty is the current sequence number of an empty log
	SeqEmpty BaseSeq = -1
)

type Seq interface {
	Seq() int64
}

// BaseSeq is the sequence number of an item in the log
// TODO currently this BaseSeq and the one in multilog somewhat do the same but not really. Find a way to unify them.
type BaseSeq int64

// Seq returns itself to adhere to the Seq interface in ./multilog.
func (s BaseSeq) Seq() int64 {
	return int64(s)
}
