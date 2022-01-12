package muxrpc

import (
	"context"
	"io"

	"github.com/pkg/errors"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/muxrpc/codec"
)

const ChunkSize = 65536

func NewSinkWriter(sink luigi.Sink) io.WriteCloser {
	return &sinkWriter{sink}
}

type sinkWriter struct {
	sink luigi.Sink
}

func (w *sinkWriter) Write(data []byte) (int, error) {
	var written int

	for len(data) > 0 {
		var block []byte

		if len(data) > ChunkSize {
			block = data[:ChunkSize]
		} else {
			block = data
		}

		err := w.sink.Pour(context.TODO(), codec.Body(block))
		if err != nil {
			return written, err
		}

		data = data[len(block):]
		written += len(block)
	}

	return written, nil
}

func (w *sinkWriter) Close() error {
	return w.sink.Close()
}

func NewSourceReader(src luigi.Source) io.Reader {
	return &srcReader{
		src: src,
	}
}

type srcReader struct {
	src luigi.Source
	buf []byte
}

func (r *srcReader) Read(data []byte) (int, error) {
	if len(r.buf) > 0 {
		n := copy(data, r.buf)
		r.buf = r.buf[n:]
		return n, nil
	}

	v, err := r.src.Next(context.TODO())
	if err != nil {
		if luigi.IsEOS(err) {
			return 0, io.EOF
		}

		return 0, errors.Wrap(err, "error getting next block")
	}

	var ok bool
	r.buf, ok = v.([]byte)
	if !ok {
		return 0, errors.Errorf("expected type %T but got %T", r.buf, v)
	}

	return r.Read(data)
}
