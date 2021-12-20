package bufpool

import (
	"bytes"
	"fmt"
)

// ChanPool maintains a free-list of buffers.
type ChanPool struct {
	ch chan *bytes.Buffer
	pc poolConfig
}

// NewChanPool creates a new FreeList. The pool size, size of new buffers, and max size of buffers
// to keep when returned to the pool can all be customized.
//
//        package main
//
//        import (
//        	"log"
//
//        	"github.com/karrick/bufpool"
//        )
//
//        func main() {
//        	bp, err := bufpool.NewChanPool()
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
func NewChanPool(setters ...Configurator) (FreeList, error) {
	pc := &poolConfig{
		poolSize: DefaultPoolSize,
		bufSize:  DefaultBufSize,
		maxKeep:  DefaultMaxKeep,
	}
	for _, setter := range setters {
		if err := setter(pc); err != nil {
			return nil, err
		}
	}
	if pc.maxKeep < pc.bufSize {
		return nil, fmt.Errorf("max buffer size must be greater or equal to default buffer size: %d, %d", pc.maxKeep, pc.bufSize)
	}
	bp := &ChanPool{
		ch: make(chan *bytes.Buffer, pc.poolSize),
		pc: *pc,
	}
	return bp, nil
}

// Get returns an initialized buffer from the free-list.
func (bp *ChanPool) Get() *bytes.Buffer {
	select {
	case bb := <-bp.ch:
		// reuse buffer
		return bb
	default:
		// empty channel: create new buffer
		return bytes.NewBuffer(make([]byte, 0, bp.pc.bufSize))
	}
}

// Put will return a used buffer back to the free-list. If the capacity of the used buffer grew
// beyond the max buffer size, it will be discarded and its memory returned to the runtime.
func (bp *ChanPool) Put(bb *bytes.Buffer) {
	if bb.Cap() > bp.pc.maxKeep {
		return // drop buffer on floor if too big
	}
	bb.Reset()
	select {
	case bp.ch <- bb: // queue buffer for reuse
	default: // drop on floor if channel full
	}
}
