package netwrap

import (
	"net"

	"github.com/pkg/errors"
)

// ConnWrapper wraps a network connection, e.g. to encrypt the transmitted content.
type ConnWrapper func(net.Conn) (net.Conn, error)

type Dialer func(net.Addr, ...ConnWrapper) (net.Conn, error)

// Dial first opens a network connection to the supplied addr, and then applies
// all the passed connection wrappers.
func Dial(addr net.Addr, wrappers ...ConnWrapper) (net.Conn, error) {
	origConn, err := net.Dial(addr.Network(), addr.String())
	if err != nil {
		return nil, errors.Wrap(err, "error dialing")
	}

	conn := origConn
	for _, cw := range wrappers {
		conn, err = cw(conn)
		if err != nil {
			origConn.Close()
			return nil, errors.Wrap(err, "error wrapping connection")
		}
	}

	return conn, nil
}
