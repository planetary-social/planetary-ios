package netwrap

import (
	"net"

	"github.com/pkg/errors"
)

// ListenerWrapper wraps a network listener.
type ListenerWrapper func(net.Listener) (net.Listener, error)

// NewListenerWrapper creates a new ListenerWrapper by wrapping all
// accepted connections with the supplied connection wrapper and wrapping
// the listener's address with the supplied address.
func NewListenerWrapper(addr net.Addr, cws ...ConnWrapper) ListenerWrapper {
	return func(l net.Listener) (net.Listener, error) {
		return &listener{
			Listener: l,

			addr:         WrapAddr(l.Addr(), addr),
			connWrappers: cws,
		}, nil
	}
}

// Listen first listens on the supplied address and then wraps that listener
// with all the supplied wrappers.
func Listen(addr net.Addr, wrappers ...ListenerWrapper) (net.Listener, error) {
	l, err := net.Listen(addr.Network(), addr.String())
	if err != nil {
		return nil, errors.Wrap(err, "netwrap: error listening")
	}

	for _, wrap := range wrappers {
		l, err = wrap(l)
		if err != nil {
			return nil, errors.Wrap(err, "netwrap: error wrapping listener")
		}
	}

	return l, nil
}

type listener struct {
	net.Listener

	addr         net.Addr
	connWrappers []ConnWrapper
}

func (l *listener) Addr() net.Addr {
	return l.addr
}

func (l *listener) Accept() (net.Conn, error) {
	conn, err := l.Listener.Accept()
	if err != nil {
		return nil, errors.Wrap(err, "netwrap: error accepting underlying connection")
	}
	origConn := conn

	for i, cw := range l.connWrappers {
		conn, err = cw(conn)
		if err != nil {
			origConn.Close()
			return nil, errors.Wrapf(err, "netwrap: error in conn wrapping function %d", i)
		}
	}
	return conn, nil
}
