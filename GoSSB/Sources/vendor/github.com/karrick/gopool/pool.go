package gopool

import "fmt"

// DefaultSize is the default number of items that will be maintained in the pool.
const DefaultSize = 10

// Pool is the interface implemented by an object that acts as a free-list resource pool.
type Pool interface {
	Close() error
	Get() interface{}
	Put(interface{})
}

type config struct {
	close   func(interface{}) error
	factory func() (interface{}, error)
	reset   func(interface{})
	size    int
}

// Configurator is a function that modifies a pool configuration structure.
type Configurator func(*config) error

// Close specifies the optional function to be called once for each resource when the Pool is
// closed.
func Close(close func(interface{}) error) Configurator {
	return func(pc *config) error {
		pc.close = close
		return nil
	}
}

// Factory specifies the function used to make new elements for the pool.  The factory function is
// called to fill the pool N times during initialization, for a pool size of N.
func Factory(factory func() (interface{}, error)) Configurator {
	return func(pc *config) error {
		pc.factory = factory
		return nil
	}
}

// Reset specifies the optional function to be called on resources when released back to the pool.
// If a reset function is not specified, then resources are returned to the pool without any reset
// step.  For instance, if maintaining a Pool of buffers, a library may choose to have the reset
// function invoke the buffer's Reset method to free resources prior to returning the buffer to the
// Pool.
func Reset(reset func(interface{})) Configurator {
	return func(pc *config) error {
		pc.reset = reset
		return nil
	}
}

// Size specifies the number of items to maintain in the pool.
func Size(size int) Configurator {
	return func(pc *config) error {
		if size <= 0 {
			return fmt.Errorf("pool size must be greater than 0: %d", size)
		}
		pc.size = size
		return nil
	}
}
