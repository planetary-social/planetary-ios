package secrethandshake

import (
	"fmt"
	"strconv"
)

var ErrInvalidKeyPair = fmt.Errorf("secrethandshake/NewKeyPair: invalid public key")

type ErrKeySize struct {
	tipe string
	n    int
}

func (eks ErrKeySize) Error() string {
	return fmt.Sprintf("secrethandshake/NewKeyPair: invalid size (%d) for %s key", eks.n, eks.tipe)
}

type ErrProtocol struct{ code int }

func (e ErrProtocol) Error() string {
	switch e.code {
	case 0:
		return "secrethandshake: Wrong protocol version?"
	case 1:
		return "secrethandshake: other side not authenticated"
	default:

		return "secrethandshake: unhandled protocol error " + strconv.Itoa(e.code)
	}
}

// ErrProcessing is returned if I/O fails during the handshake
// TODO: supply Unwrap() for cause?
type ErrProcessing struct {
	where string
	cause error
}

func (e ErrProcessing) Error() string {
	errStr := "secrethandshake: failed during data transfer of " + e.where
	errStr += ": " + e.cause.Error()
	return errStr
}

// Unwrap returns the cause
func (e ErrProcessing) Unwrap() error { return e.cause }

type ErrEncoding struct {
	what  string
	cause error
}

func (e ErrEncoding) Error() string {
	errStr := "secrethandshake: failed during encoding task of " + e.what
	errStr += ": " + e.cause.Error()
	return errStr
}

// Unwrap returns the cause
func (e ErrEncoding) Unwrap() error { return e.cause }
