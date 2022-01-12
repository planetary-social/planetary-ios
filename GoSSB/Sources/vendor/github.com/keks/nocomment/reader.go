// nocomment provides a reader that strips away everything between a # and a newline (including the #)
package nocomment

import (
	"bytes"
	"io"
	"sync"
)

// NewReader wraps the passed reader to clean the read data from #-style comments.
func NewReader(r io.Reader) io.Reader {
	return &reader{r: r}
}

type reader struct {
	l         sync.Mutex
	r         io.Reader
	inComment bool
}

func (r *reader) Read(data []byte) (int, error) {
	r.l.Lock()
	defer r.l.Unlock()

	n, err := r.r.Read(data)
	n = r.rd(data, n)
	return n, err
}

func (r *reader) rd(data []byte, n int) int {
	if n == 0 { return 0 }

	if r.inComment {
		i := bytes.IndexByte(data[:n], '\n')
		if i == -1 {
			return 0
		}

		copy(data, data[i:n])
		r.inComment = false
		return r.rd(data, n-i)
	} else {
		i := bytes.IndexByte(data[:n], '#')
		if i == -1 {
			return n
		}

		r.inComment = true
		return i + r.rd(data[i:n], n-i)
	}
}
