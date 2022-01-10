// SPDX-License-Identifier: MIT

package librarian

import (
	"sync"

	"go.cryptoscope.co/luigi"
)

// NewObservable returns a regular observable that calls f when the last registration is cancelled.
// This is used to garbage-collect observables from the maps in the indexes.
func NewObservable(v interface{}, f func()) luigi.Observable {
	return &observable{
		Observable: luigi.NewObservable(v),
		f:          f,
	}
}

// observable is a regular luigi.Observable that calls f once all registrations are cancelled
type observable struct {
	luigi.Observable

	l sync.Mutex
	i int
	f func()
}

// Register registers sink with the observable.
func (obv *observable) Register(sink luigi.Sink) func() {
	obv.l.Lock()
	defer obv.l.Unlock()

	obv.i++
	cancel := obv.Observable.Register(sink)

	return func() {
		cancel()

		obv.l.Lock()
		defer obv.l.Unlock()

		obv.i--

		if obv.i == 0 {
			obv.f()
		}
	}
}
