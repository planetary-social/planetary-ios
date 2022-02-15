package encodedTime

import (
	"bytes"
	"math"
	"strconv"
	"time"
)

// Millisecs is used to get a time from an js number that represents a timestamp in milliseconds
type Millisecs time.Time

// NewMillisecs returns a Millisecs instance with secs converted to millisecs (*1000)
func NewMillisecs(secs int64) Millisecs {
	return Millisecs(time.Unix(secs, 0))
}

func (t *Millisecs) UnmarshalJSON(in []byte) (err error) {
	dot := []byte{'.'}
	i := bytes.Index(in, dot)
	if i == -1 {
		i = 1000
	} else {
		i = int(math.Pow(10, float64(len(in)-i-2)))
		in = bytes.Replace(in, dot, []byte{}, 1)
	}
	secs, err := strconv.ParseInt(string(in), 10, 64)
	if err != nil {
		return err
	}

	*t = Millisecs(time.Unix(secs/int64(i), 0))
	return nil
}

func (t Millisecs) MarshalJSON() ([]byte, error) {
	secs := time.Time(t).UnixNano() / 1000000
	return []byte(strconv.FormatInt(secs, 10)), nil
}
