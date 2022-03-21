# bufpool

Go library for using a free-list of byte buffers.

## Background

A few excellent articles were published that resurfaced the topic of using free-lists of byte.Buffer
structures in Go.  Because the Go runtime includes facilities to manage free-lists, I was curious
about the performance characteristics of various methods of achieving this goal, and decided to
benchmark these options.

* https://blog.cloudflare.com/recycling-memory-buffers-in-go/
* https://elithrar.github.io/article/using-buffer-pools-with-go/

## Description

Several free-list algorithms are included to allow selection of whichever performs best for a
particular application scenario.

* NewChanPool         -- uses Go channels to provide concurrent access to internal structures
* NewLockPool         -- uses sync.Mutex to provide concurrent access to internal structures
* NewSyncPool         -- uses sync.Pool to provide concurrent access to internal structures
* NewPreAllocatedPool -- wrapper around github.com/karrick/gopool, which uses Go channels to provide concurrent access to internal structures

Each of these algorithms performs quite differently when run on different architectures, and with
different amounts of concurrency.

Benchmark functions are provided to determine which buffer free-list algorithm best suits a given
application.

### Usage

Documentation is available via
[![GoDoc](https://godoc.org/github.com/karrick/bufpool?status.svg)](https://godoc.org/github.com/karrick/bufpool).

### Example

The most basic example is creating a buffer pool and using it.

```Go
    package main
    
    import (
    	"log"
    	"github.com/karrick/bufpool"
    )
    
    func main() {
    	bp, err := bufpool.NewChanPool()
    	if err != nil {
    		log.Fatal(err)
    	}
    
    	// NOTE: silly example with heavy resource contension
    	for i := 0; i < 4*bufpool.DefaultPoolSize; i++ {
    		go func() {
    			for j := 0; j < 1000; j++ {
    				bb := bp.Get()
    				// NOTE: buffer is ready to use
    				for k := 0; k < bufpool.DefaultBufSize/2; k++ {
    					bb.WriteByte(byte(k % 256))
    				}
    				// NOTE: no need to reset buffer prior to release
    				bp.Put(bb)
    			}
    		}()
    	}
    }
```

During buffer pool creation, you may specify the size of newly allocated buffers, the max keep size
of a buffer returned to the pool, and the size of the pool.

The max keep size does not mean the maximum size a buffer is allowed to grow. Instead, when a buffer
is returned to the pool, if that buffer has grown beyond the specified max keep size, it will be
garbage collected, releasing its memory back to the runtime rather than sit in the pool.  This
prevents an unusual use of a buffer that grows extremely large from holding onto that memory
indefinitely.

Ideally one determines what the pool size, initial buffer size, and max buffer size should be for
their application, and sets these values when creating the buffer pool.

```Go
    package main

    import (
        "log"
        "github.com/karrick/bufpool"
    )

    func main() {
        // NOTE: All variants of bufpool.New*() can have one or more of BufSize(), MaxKeep(), and PoolSize()
        // to customize the created bufpool.FreeList.
        bp, err := bufpool.NewChanPool(bufpool.PoolSize(64), BufSize(16*1024), MaxKeep(128*1024))
        if err != nil {
            log.Fatal(err)
        }
        // as before...
    }
```
