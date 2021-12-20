package gopool

import (
	"errors"
	"strings"
	"sync"
)

const (
	putBlocks = iota
	getBocks
	neitherBlocks
)

// ArrayPool implements the Pool interface, maintaining a pool of resources.
type ArrayPool struct {
	cond    *sync.Cond
	blocked int // putBlocks | getBlocks | neitherBlocks
	pc      config
	gi      int // index of next Get
	pi      int // index of next Put
	items   []interface{}
}

// NewArrayPool creates a new Pool. The factory method used to create new items for the Pool must be
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
//		bp, err := gopool.NewArrayPool(gopool.Size(poolSize), gopool.Factory(makeBuffer), gopool.Reset(resetBuffer))
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
func NewArrayPool(setters ...Configurator) (Pool, error) {
	pc := config{
		size: DefaultSize,
	}
	for _, setter := range setters {
		if err := setter(&pc); err != nil {
			return nil, err
		}
	}
	if pc.factory == nil {
		return nil, errors.New("cannot create pool without specifying a factory method")
	}
	pool := &ArrayPool{
		blocked: putBlocks,
		cond:    &sync.Cond{L: &sync.Mutex{}},
		items:   make([]interface{}, pc.size),
		pc:      pc,
	}
	for i := 0; i < pool.pc.size; i++ {
		item, err := pool.pc.factory()
		if err != nil {
			if pool.pc.close != nil {
				_ = pool.Close() // ignore error; want user to get error from factory call
			}
			return nil, err
		}
		pool.items[i] = item
	}
	return pool, nil
}

func (pool *ArrayPool) Get() interface{} {
	// Get blocks when attempt to Get made at location next Put goes to
	pool.cond.L.Lock()
	for pool.blocked == getBocks {
		pool.cond.Wait()
	}
	item := pool.items[pool.gi]

	pool.gi = (pool.gi + 1) % pool.pc.size
	if pool.gi == pool.pi {
		pool.blocked = getBocks
	} else {
		pool.blocked = neitherBlocks
	}

	pool.cond.L.Unlock()
	pool.cond.Broadcast()
	return item
}

// Put will release a resource back to the pool. Put blocks if pool already full. If the Pool was
// initialized with a Reset function, it will be invoked with the resource as its sole argument,
// prior to the resource being added back to the pool. If Put is called when adding the resource to
// the pool _would_ result in having more elements in the pool than the pool size, the resource is
// effectively dropped on the floor after calling any optional Reset and Close methods on the
// resource.
func (pool *ArrayPool) Put(item interface{}) {
	if pool.pc.reset != nil {
		pool.pc.reset(item)
	}

	// Put blocks when attempt to Put made at location next Get comes from
	pool.cond.L.Lock()
	for pool.blocked == putBlocks {
		pool.cond.Wait()
	}
	pool.items[pool.pi] = item

	pool.pi = (pool.pi + 1) % pool.pc.size
	if pool.gi == pool.pi {
		pool.blocked = putBlocks
	} else {
		pool.blocked = neitherBlocks
	}

	pool.cond.L.Unlock()
	pool.cond.Broadcast()
}

// Close is called when the Pool is no longer needed, and the resources in the Pool ought to be
// released.  If a Pool has a close function, it will be invoked one time for each resource, with
// that resource as its sole argument.
func (pool *ArrayPool) Close() error {
	pool.cond.L.Lock()
	defer pool.cond.L.Unlock()

	var errs []error
	if pool.pc.close != nil {
		for _, item := range pool.items {
			if err := pool.pc.close(item); err != nil {
				errs = append(errs, err)
			}
		}
	}

	// prevent use of pool after Close
	pool.items = nil
	pool.gi = 0
	pool.pi = 0
	pool.blocked = getBocks

	if len(errs) == 0 {
		return nil
	}
	var messages []string
	for _, err := range errs {
		messages = append(messages, err.Error())
	}
	return errors.New(strings.Join(messages, ", "))
}
