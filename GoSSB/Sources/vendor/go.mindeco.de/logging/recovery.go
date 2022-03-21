package logging

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"runtime/debug"

	"github.com/davecgh/go-spew/spew"
	"github.com/pkg/errors"
)

// RecoveryHandler recovers handler panics and logs them using LogPanicWithStack
func RecoveryHandler() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			defer func() {
				if r := recover(); r != nil {
					log := FromContext(req.Context())
					if log == nil {
						log = Logger("RecoveryHandler")
					}
					if err := LogPanicWithStack(log, "httpRecovery", r); err != nil {
						fmt.Fprintf(os.Stderr, "PanicLog failed! %q", err)
						panic(err)
					}
					http.Error(w, "internal processing failure - error has been reported", http.StatusInternalServerError)
				}
			}()
			next.ServeHTTP(w, req)
		})
	}
}

// LogPanicWithStack writes the passed value r, together with a debug.Stack to a tmpfile and logs its location
func LogPanicWithStack(log Interface, location string, r interface{}, vals ...interface{}) error {
	if log == nil {
		log = internal
	}
	var err error
	switch t := r.(type) {
	case string:
		err = errors.New(t)
	case error:
		err = t
	default:
		err = errors.Errorf("unkown type(%T) error: %v", r, r)
	}
	os.Mkdir("panics", os.ModePerm)
	b, tmpErr := ioutil.TempFile("panics", location)
	if tmpErr != nil {
		log.Log("event", "panic", "location", location, "err", err, "warning", "no temp file", "tmperr", tmpErr)
		return errors.Wrapf(tmpErr, "LogPanic: failed to create httpRecovery log")
	}

	fmt.Fprintf(b, "warning! %s!\nError:\n%+v\n", location, err)
	for i, v := range vals {
		spew.Fdump(b, "val(%d): %#v\n", i, v)
	}
	fmt.Fprintf(b, "\n\nCall Stack:\n%s", debug.Stack())

	log.Log("event", "panic", "location", location, "panicLog", b.Name(), "err", err)

	return errors.Wrap(b.Close(), "LogPanic: failed to close dump file")
}
