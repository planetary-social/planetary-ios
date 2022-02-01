// SPDX-License-Identifier: MIT

package margaret

// SeqWrapper wraps a value to attach a sequence number to it.
type SeqWrapper interface {
	Seqer

	// Value returns the item itself.
	Value() interface{}
}

type seqWrapper struct {
	seq int64
	v   interface{}
}

func (sw *seqWrapper) Seq() int64 {
	return sw.seq
}

func (sw *seqWrapper) Value() interface{} {
	return sw.v
}

// WrapWithSeq wraps the value v to attach a sequence number to it.
func WrapWithSeq(v interface{}, seq int64) SeqWrapper {
	return &seqWrapper{
		seq: seq,
		v:   v,
	}
}
