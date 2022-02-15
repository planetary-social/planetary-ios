// SPDX-License-Identifier: MIT

package librarian // import "go.cryptoscope.co/librarian"

type Marshaler interface {
	Marshal() ([]byte, error)
}

type Unmarshaler interface {
	Unmarshal([]byte) error
}
