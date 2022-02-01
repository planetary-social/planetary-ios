# gopool

Gopool offers a way to maintain a free-list, or a pool of resources in
Go programs.

## Description

It is often the case that resource setup and teardown can be quite
demanding, and it is desirable to reuse resources rather than close
them and create new ones when needed. Two such examples are network
sockets to a given peer, and large byte buffers for building query
responses.

Although most customizations are optional, it does require
specification of a customized setup function to create new resources.
Optional resources include specifying the size of the resource pool,
specifying a per-use reset function, and specifying a close function
to be called when the pool is no longer needed. The close function is
called one time for each resource in the pool, with that resource as
the close function's sole argument.

### Usage

Documentation is available via
[![GoDoc](https://godoc.org/github.com/karrick/gopool?status.svg)](https://godoc.org/github.com/karrick/gopool).

### Example

The most basic example is creating a buffer pool and using it.

WARNING: You Must ensure resource returns to pool otherwise gopool will deadlock once all resources
used. If you use the resource in a function, consider using `defer pool.Put(bb)` immediately after
you obtain the resource at the top of your function.

```Go
    package main

    import (
        "bytes"
        "errors"
        "fmt"
        "log"
        "math/rand"
        "sync"

        "github.com/karrick/gopool"
    )

    const (
        bufSize  = 64 * 1024
        poolSize = 25
    )

    func main() {
        const iterationCount = 1000
        const parallelCount = 100

        makeBuffer := func() (interface{}, error) {
            return bytes.NewBuffer(make([]byte, 0, bufSize)), nil
        }

        resetBuffer := func(item interface{}) {
            item.(*bytes.Buffer).Reset()
        }

        bp, err := gopool.New(gopool.Size(poolSize), gopool.Factory(makeBuffer), gopool.Reset(resetBuffer))
        if err != nil {
            log.Fatal(err)
        }

        var wg sync.WaitGroup
        wg.Add(parallelCount)

        for i := 0; i < parallelCount; i++ {
            go func() {
                defer wg.Done()

                for j := 0; j < iterationCount; j++ {
                    if err := grabBufferAndUseIt(bp); err != nil {
                        fmt.Println(err)
                        return
                    }
                }
            }()
        }
        wg.Wait()
    }

    func grabBufferAndUseIt(pool gopool.Pool) error {
        // WARNING: Must ensure resource returns to pool otherwise gopool will deadlock once all
        // resources used.
        bb := pool.Get().(*bytes.Buffer)
        defer pool.Put(bb) // IMPORTANT: defer here to ensure invoked even when subsequent code bails

        for k := 0; k < bufSize; k++ {
            if rand.Intn(100000000) == 1 {
                return errors.New("random error to illustrate need to return resource to pool")
            }
            bb.WriteByte(byte(k % 256))
        }
        return nil
    }
```
