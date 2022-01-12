// SPDX-License-Identifier: MIT

package margaret

// SeqWrapper wraps a value to attach a sequence number to it.
type SeqWrapper interface {
	// Seq returns the sequence number of the item.
	Seq() Seq

	// Value returns the item itself.
	Value() interface{}
}

type seqWrapper struct {
	seq Seq
	v   interface{}
}

func (sw *seqWrapper) Seq() Seq {
	return sw.seq
}

func (sw *seqWrapper) Value() interface{} {
	return sw.v
}

// WrapWithSeq wraps the value v to attach a sequence number to it.
func WrapWithSeq(v interface{}, seq Seq) SeqWrapper {
	return &seqWrapper{
		seq: seq,
		v:   v,
	}
}
