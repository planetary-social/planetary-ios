package bufpool

import (
	"bytes"
	"fmt"

	"github.com/karrick/gopool"
)

type preAllocated struct {
	pool    gopool.Pool
	maxKeep int
	factory func() (interface{}, error)
}

func NewPreAllocatedPool(setters ...Configurator) (FreeList, error) {
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

	var err error

	makeBuffer := func() (interface{}, error) {
		return bytes.NewBuffer(make([]byte, pc.bufSize)), nil
	}

	p, err := gopool.New(gopool.Factory(makeBuffer), gopool.Size(pc.poolSize))
	if err != nil {
		return nil, err
	}

	return &preAllocated{
		pool:    p,
		maxKeep: pc.maxKeep,
		factory: makeBuffer,
	}, nil
}

func (p *preAllocated) Get() *bytes.Buffer {
	return p.pool.Get().(*bytes.Buffer)
}

func (p *preAllocated) Put(bb *bytes.Buffer) {
	if bb.Cap() > p.maxKeep {
		if newBB, err := p.factory(); err == nil {
			p.pool.Put(newBB.(*bytes.Buffer))
			// drop bb on the floor for GC
			return
		}
		// if err creating new buffer, then just re-use bb
	}
	bb.Reset()
	p.pool.Put(bb)
}
