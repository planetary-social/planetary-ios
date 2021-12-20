package gopool

import (
	"errors"
	"strings"
)

// ChanPool implements the Pool interface, maintaining a pool of resources.
type ChanPool struct {
	ch chan interface{}
	pc config
}

// New creates a new Pool. The factory method used to create new items for the Pool must be
// specified using the gopool.Factory method. Optionally, the pool size and a reset function can be
// specified.
//
//	package main
//
//	import (
//		"bytes"
//		"errors"
//		"fmt"
//		"log"
//		"math/rand"
//		"sync"
//
//		"github.com/karrick/gopool"
//	)
//
//	const (
//		bufSize  = 64 * 1024
//		poolSize = 25
//	)
//
//	func main() {
//		const iterationCount = 1000
//		const parallelCount = 100
//
//		makeBuffer := func() (interface{}, error) {
//			return bytes.NewBuffer(make([]byte, 0, bufSize)), nil
//		}
//
//		resetBuffer := func(item interface{}) {
//			item.(*bytes.Buffer).Reset()
//		}
//
//		bp, err := gopool.New(gopool.Size(poolSize), gopool.Factory(makeBuffer), gopool.Reset(resetBuffer))
//		if err != nil {
//			log.Fatal(err)
//		}
//
//		var wg sync.WaitGroup
//		wg.Add(parallelCount)
//
//		for i := 0; i < parallelCount; i++ {
//			go func() {
//				defer wg.Done()
//
//				for j := 0; j < iterationCount; j++ {
//					if err := grabBufferAndUseIt(bp); err != nil {
//						fmt.Println(err)
//						return
//					}
//				}
//			}()
//		}
//		wg.Wait()
//	}
//
//	func grabBufferAndUseIt(pool gopool.Pool) error {
//		// WARNING: Must ensure resource returns to pool otherwise gopool will deadlock once all
//		// resources used.
//		bb := pool.Get().(*bytes.Buffer)
//		defer pool.Put(bb) // IMPORTANT: defer here to ensure invoked even when subsequent code bails
//
//		for k := 0; k < bufSize; k++ {
//			if rand.Intn(100000000) == 1 {
//				return errors.New("random error to illustrate need to return resource to pool")
//			}
//			bb.WriteByte(byte(k % 256))
//		}
//		return nil
//	}
func New(setters ...Configurator) (Pool, error) {
	pc := &config{
		size: DefaultSize,
	}
	for _, setter := range setters {
		if err := setter(pc); err != nil {
			return nil, err
		}
	}
	if pc.factory == nil {
		return nil, errors.New("ought to specify factory method")
	}
	pool := &ChanPool{
		ch: make(chan interface{}, pc.size),
		pc: *pc,
	}
	for i := 0; i < pool.pc.size; i++ {
		item, err := pool.pc.factory()
		if err != nil {
			return nil, err
		}
		pool.ch <- item
	}
	return pool, nil
}

// Get acquires and returns an item from the pool of resources. Get blocks while there are no items in the pool.
func (pool *ChanPool) Get() interface{} {
	return <-pool.ch
}

// Put will release a resource back to the pool. Put blocks if pool already full. If the Pool was
// initialized with a Reset function, it will be invoked with the resource as its sole argument,
// prior to the resource being added back to the pool. If Put is called when adding the resource to
// the pool _would_ result in having more elements in the pool than the pool size, the resource is
// effectively dropped on the floor after calling any optional Reset and Close methods on the
// resource.
func (pool *ChanPool) Put(item interface{}) {
	if pool.pc.reset != nil {
		pool.pc.reset(item)
	}
	pool.ch <- item
}

// Close is called when the Pool is no longer needed, and the resources in the Pool ought to be
// released.  If a Pool has a close function, it will be invoked one time for each resource, with
// that resource as its sole argument.
func (pool *ChanPool) Close() error {
	var errs []error
	for {
		select {
		case item := <-pool.ch:
			if pool.pc.close != nil {
				if err := pool.pc.close(item); err != nil {
					errs = append(errs, err)
				}
			}
		default:
			if len(errs) == 0 {
				return nil
			}
			var messages []string
			for _, err := range errs {
				messages = append(messages, err.Error())
			}
			return errors.New(strings.Join(messages, ", "))
		}
	}
}
