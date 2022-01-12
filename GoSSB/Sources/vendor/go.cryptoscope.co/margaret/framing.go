// SPDX-License-Identifier: MIT

package margaret // import "go.cryptoscope.co/margaret"

// Framing encodes and decodes byte slices into a framing so the frames can be stored sequentially
type Framing interface {
	DecodeFrame([]byte) ([]byte, error)
	EncodeFrame([]byte) ([]byte, error)

	FrameSize() int64
}
