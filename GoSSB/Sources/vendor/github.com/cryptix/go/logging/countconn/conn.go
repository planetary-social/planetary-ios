package countconn

import (
	"net"
	"time"

	"github.com/dustin/go-humanize"
	"github.com/go-kit/kit/log"
)

type Conn struct {
	*Reader
	*Writer
	conn net.Conn

	logger log.Logger
}

func WrapConn(logger log.Logger, c net.Conn) net.Conn {
	wrap := Conn{
		logger: logger,
		conn:   c,
	}
	wrap.Reader = NewReader(c)
	wrap.Writer = NewWriter(c)
	return &wrap
}

func (c *Conn) Close() error {
	c.logger.Log("conn", "closed",
		"local", c.conn.LocalAddr().String(),
		"remote", c.conn.RemoteAddr(),
		"tx", humanize.Bytes(uint64(c.Writer.N())),
		"rx", humanize.Bytes(uint64(c.Reader.N())),
	)
	return c.conn.Close()
}

func (c *Conn) LocalAddr() net.Addr                { return c.conn.LocalAddr() }
func (c *Conn) RemoteAddr() net.Addr               { return c.conn.RemoteAddr() }
func (c *Conn) SetDeadline(t time.Time) error      { return c.conn.SetDeadline(t) }
func (c *Conn) SetReadDeadline(t time.Time) error  { return c.conn.SetReadDeadline(t) }
func (c *Conn) SetWriteDeadline(t time.Time) error { return c.conn.SetWriteDeadline(t) }
