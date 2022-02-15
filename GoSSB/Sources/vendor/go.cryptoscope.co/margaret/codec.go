// SPDX-License-Identifier: MIT

package margaret // import "go.cryptoscope.co/margaret"

import (
	"io"
)

// Codec marshals and unmarshals values and creates encoders and decoders
type Codec interface {
	// Marshal encodes a single value and returns the serialized byte slice.
	Marshal(value interface{}) ([]byte, error)

	// Unmarshal decodes and returns the value stored in data.
	Unmarshal(data []byte) (interface{}, error)

	NewDecoder(io.Reader) Decoder
	NewEncoder(io.Writer) Encoder
}

// Decoder decodes values
type Decoder interface {
	Decode() (interface{}, error)
}

// Encoder encodes values
type Encoder interface {
	Encode(v interface{}) error
}
