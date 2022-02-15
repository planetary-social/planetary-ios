// SPDX-License-Identifier: MIT

package margaret // import "go.cryptoscope.co/margaret"

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -o mock/qry.go . Query

// Query is the interface implemented by the concrete log implementations that collects the constraints of the query.
type Query interface {
	// Gt makes the source return only items with sequence numbers > seq.
	Gt(seq Seq) error
	// Gte makes the source return only items with sequence numbers >= seq.
	Gte(seq Seq) error
	// Lt makes the source return only items with sequence numbers < seq.
	Lt(seq Seq) error
	// Lte makes the source return only items with sequence numbers <= seq.
	Lte(seq Seq) error
	// Limit makes the source return only up to n items.
	Limit(n int) error

	// Reverse makes the source return the lastest values first
	Reverse(yes bool) error

	// Live makes the source block at the end of the log and wait for new values
	// that are being appended.
	Live(bool) error

	// SeqWrap makes the source return values that contain both the item and its
	// sequence number, instead of the item alone.
	SeqWrap(bool) error
}

// QuerySpec is a constraint on the query.
type QuerySpec func(Query) error

// MergeQuerySpec collects several contraints and merges them into one.
func MergeQuerySpec(spec ...QuerySpec) QuerySpec {
	return func(qry Query) error {
		for _, f := range spec {
			err := f(qry)
			if err != nil {
				return err
			}
		}

		return nil
	}
}

// ErrorQuerySpec makes the log.Query call return the passed error.
func ErrorQuerySpec(err error) QuerySpec {
	return func(Query) error {
		return err
	}
}

// Gt makes the source return only items with sequence numbers > seq.
func Gt(s Seq) QuerySpec {
	return func(q Query) error {
		return q.Gt(s)
	}
}

// Gte makes the source return only items with sequence numbers >= seq.
func Gte(s Seq) QuerySpec {
	return func(q Query) error {
		return q.Gte(s)
	}
}

// Lt makes the source return only items with sequence numbers < seq.
func Lt(s Seq) QuerySpec {
	return func(q Query) error {
		return q.Lt(s)
	}
}

// Lte makes the source return only items with sequence numbers <= seq.
func Lte(s Seq) QuerySpec {
	return func(q Query) error {
		return q.Lte(s)
	}
}

// Limit makes the source return only up to n items.
func Limit(n int) QuerySpec {
	return func(q Query) error {
		return q.Limit(n)
	}
}

// Live makes the source block at the end of the log and wait for new values
// that are being appended.
func Live(live bool) QuerySpec {
	return func(q Query) error {
		return q.Live(live)
	}
}

// SeqWrap makes the source return values that contain both the item and its
// sequence number, instead of the item alone.
func SeqWrap(wrap bool) QuerySpec {
	return func(q Query) error {
		return q.SeqWrap(wrap)
	}
}

func Reverse(yes bool) QuerySpec {
	return func(q Query) error {
		return q.Reverse(yes)
	}
}
