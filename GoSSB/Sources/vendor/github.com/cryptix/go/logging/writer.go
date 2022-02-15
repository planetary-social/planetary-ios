package logging

import (
	"bufio"
	"io"

	kitlog "github.com/go-kit/kit/log"
)

// Writer returns a writer which logs each line that is written to it using a bufio.Scanner
func Writer(unit string, l kitlog.Logger) io.WriteCloser {
	l = kitlog.With(l, "unit", unit)
	pr, pw := io.Pipe()
	go func() {
		s := bufio.NewScanner(pr)
		for s.Scan() {
			l.Log("msg", s.Text())
		}
		if err := s.Err(); err != nil {
			l.Log("msg", "scanner error", "err", err)
		}
	}()
	return pw
}
