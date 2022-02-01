package keys

import "fmt"

type ErrorCode uint8

const (
	ErrorCodeInternal ErrorCode = iota
	ErrorCodeInvalidKeyScheme
	ErrorCodeNoSuchKey
)

func (code ErrorCode) String() string {
	switch code {
	case ErrorCodeInternal:
		return "keys: internal error"
	case ErrorCodeNoSuchKey:
		return "keys: no such key found"
	case ErrorCodeInvalidKeyScheme:
		return "keys: invalid scheme"
	default:
		panic("unhandled error code")
	}
}

type Error struct {
	Code   ErrorCode
	Scheme KeyScheme
	ID     ID

	// TODO: add unwrap
	Cause error
}

func (err Error) Error() string {
	if err.Code == ErrorCodeInternal {
		return err.Cause.Error()
	}

	return fmt.Sprintf("%s at (%s, %x)", err.Code, err.Scheme, err.ID)
}

func IsNoSuchKey(err error) bool {
	if err_, ok := err.(Error); !ok {
		return false
	} else {
		return err_.Code == ErrorCodeNoSuchKey
	}
}
