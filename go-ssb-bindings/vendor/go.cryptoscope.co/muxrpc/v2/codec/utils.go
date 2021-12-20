package codec

import (
	"errors"
	"fmt"
	"io"
)

func ReadAllPackets(rd *Reader) ([]*Packet, error) {
	var pkts []*Packet
	var hdr Header
	for {
		err := rd.ReadHeader(&hdr)
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, err
		}

		var pkt = new(Packet)

		pkt.Flag = hdr.Flag
		pkt.Req = hdr.Req
		pkt.Body = make([]byte, hdr.Len)

		_, err = io.ReadFull(rd.NextBodyReader(hdr.Len), pkt.Body)
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, fmt.Errorf("muxrpc: failed to get error body for closing of %d", hdr.Req)
		}
		pkts = append(pkts, pkt)
	}
	return pkts, nil
}
