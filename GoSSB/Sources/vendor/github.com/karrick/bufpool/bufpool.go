package bufpool

import (
	"bytes"
	"fmt"
)

// DefaultBufSize is the default size used to create new buffers.
const DefaultBufSize = 4 * 1024

// DefaultMaxKeep is the default size used to determine whether to keep buffers returned to the
// pool.
const DefaultMaxKeep = 16 * 1024

// DefaultPoolSize is the default number of buffers that the free-list will maintain.
const DefaultPoolSize = 100

// FreeList represents a data structure that maintains a free-list of buffers, accesible via Get and
// Put methods.
type FreeList interface {
	Get() *bytes.Buffer
	Put(*bytes.Buffer)
}

type poolConfig struct {
	bufSize, maxKeep, poolSize int
}

// Configurator is a function that modifies a pool configuration structure.
type Configurator func(*poolConfig) error

// BufSize specifies the size of newly allocated buffers.
//
//        package main
//
//        import (
//        	"log"
//        	"github.com/karrick/bufpool"
//        )
//
//        func main() {
//        	bp, err := bufpool.NewChanPool(bufpool.BufSize(1024))
//        	if err != nil {
//        		log.Fatal(err)
//        	}
//        	for i := 0; i < 4*bufpool.DefaultPoolSize; i++ {
//        		go func() {
//        			for j := 0; j < 1000; j++ {
//        				bb := bp.Get()
//        				for k := 0; k < 3*bufpool.DefaultBufSize; k++ {
//        					bb.WriteByte(byte(k % 256))
//        				}
//        				bp.Put(bb)
//        			}
//        		}()
//        	}
//        }
func BufSize(size int) Configurator {
	return func(pc *poolConfig) error {
		if size <= 0 {
			return fmt.Errorf("default buffer size must be greater than 0: %d", size)
		}
		pc.bufSize = size
		return nil
	}
}

// MaxKeep specifies the maximum size of buffers that ought to be kept when returned to the free
// list.  Buffers with a capacity larger than this size will be discarded, and their memory returned
// to the runtime.
//
//        package main
//
//        import (
//        	"log"
//        	"github.com/karrick/bufpool"
//        )
//
//        func main() {
//        	bp, err := bufpool.NewChanPool(bufpool.MaxKeep(32 * 1024))
//        	if err != nil {
//        		log.Fatal(err)
//        	}
//        	for i := 0; i < 4*bufpool.DefaultPoolSize; i++ {
//        		go func() {
//        			for j := 0; j < 1000; j++ {
//        				bb := bp.Get()
//        				for k := 0; k < 3*bufpool.DefaultBufSize; k++ {
//        					bb.WriteByte(byte(k % 256))
//        				}
//        				bp.Put(bb)
//        			}
//        		}()
//        	}
//        }
func MaxKeep(size int) Configurator {
	return func(pc *poolConfig) error {
		if size <= 0 {
			return fmt.Errorf("max buffer size must be greater than 0: %d", size)
		}
		pc.maxKeep = size
		return nil
	}
}

// PoolSize specifies the number of buffers to maintain in the pool.  This option has no effect,
// however, on free-lists created with NewSyncPool, because the Go runtime dynamically maintains the
// size of pools created using sync.Pool.
//
//        package main
//
//        import (
//        	"log"
//        	"github.com/karrick/bufpool"
//        )
//
//        func main() {
//        	bp, err := bufpool.NewChanPool(bufpool.PoolSize(25))
//        	if err != nil {
//        		log.Fatal(err)
//        	}
//        	for i := 0; i < 4*bufpool.DefaultPoolSize; i++ {
//        		go func() {
//        			for j := 0; j < 1000; j++ {
//        				bb := bp.Get()
//        				for k := 0; k < 3*bufpool.DefaultBufSize; k++ {
//        					bb.WriteByte(byte(k % 256))
//        				}
//        				bp.Put(bb)
//        			}
//        		}()
//        	}
//        }
func PoolSize(size int) Configurator {
	return func(pc *poolConfig) error {
		if size <= 0 {
			return fmt.Errorf("pool size must be greater than 0: %d", size)
		}
		pc.poolSize = size
		return nil
	}
}
