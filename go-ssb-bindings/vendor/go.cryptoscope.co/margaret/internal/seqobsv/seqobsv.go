// Package seqobsv wants to supply an observable value sepcialized for sequence numbers in append-only logs.
// It should be fine for access from multiple goroutines.
//
// These values only go up by one. For margaret they start with 0.
//
package seqobsv

import (
	"math"
	"sync"
)

type Observable struct {
	mu  sync.Mutex
	val uint64

	waiters waitMap
}

type emptyChan chan struct{}
type waitMap map[uint64][]emptyChan

// New creates a new Observable
func New(start uint64) *Observable {
	return &Observable{
		val:     start,
		waiters: make(waitMap),
	}
}

// Value returns the current value
func (seq *Observable) Value() uint64 {
	seq.mu.Lock()
	v := seq.val
	seq.mu.Unlock()
	return v
}

func (seq *Observable) Seq() int64 {
	seq.mu.Lock()
	v := seq.val
	seq.mu.Unlock()
	if v > math.MaxInt64 {
		panic("bigger then int64")
	}
	return int64(v)
}

func (seq *Observable) Inc() uint64 {
	seq.mu.Lock()
	curr := seq.val

	if waiters, has := seq.waiters[curr]; has {
		for _, ch := range waiters {
			close(ch)
		}
		delete(seq.waiters, curr)
	}
	seq.val = seq.val + 1
	currVal := seq.val
	seq.mu.Unlock()
	return currVal
}

func (seq *Observable) WaitFor(n uint64) <-chan struct{} {
	seq.mu.Lock()
	defer seq.mu.Unlock()
	ch := make(emptyChan)
	if n < seq.val {
		go func() { close(ch) }()
		return ch
	}

	waitersForN, has := seq.waiters[n]
	if !has {
		waitersForN = make([]emptyChan, 0)
	}

	seq.waiters[n] = append(waitersForN, ch)
	return ch
}
