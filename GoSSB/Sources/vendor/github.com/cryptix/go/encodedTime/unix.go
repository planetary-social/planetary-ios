package encodedTime

import (
	"strconv"
	"time"
)

// Unix converts unix times to time.Time
type Unix time.Time

// NewUnix returns a Unix instance with secs since unix-0
func NewUnix(secs int64) Unix {
	return Unix(time.Unix(secs, 0))
}

// UnmarshalJSON for Unix converts the []byte value to int64 seconds and than constructs the time with time.Unix()
func (t *Unix) UnmarshalJSON(in []byte) (err error) {
	secs, err := strconv.ParseInt(string(in), 10, 64)
	if err != nil {
		return err
	}

	*t = Unix(time.Unix(secs, 0))
	return nil
}

// MarshalJSON takes the Unix() seconds from the time and uses strconv.FormatInt() to return the string of digits
func (t Unix) MarshalJSON() ([]byte, error) {
	secs := time.Time(t).Unix()
	return []byte(strconv.FormatInt(secs, 10)), nil
}
