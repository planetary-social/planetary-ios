package muxrpc

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"time"

	"go.cryptoscope.co/muxrpc/v2/codec"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"
)

const manifestTimeout = 1 * time.Minute

// ask the remote for their sets of supported methods (the manifest) and store it in the rpc session
func (r *rpc) retreiveManifest() {
	ctx, cancel := context.WithTimeout(r.serveCtx, manifestTimeout)
	defer cancel()

	var req = Request{
		Type: "sync",

		sink:   newByteSink(ctx, r.pkr.w),
		source: newByteSource(ctx, r.bpool),

		Method:  Method{"manifest"},
		RawArgs: json.RawMessage(`[]`),

		abort: func() {},
	}

	var (
		pkt codec.Packet
		err error

		dbg = log.With(level.Debug(r.logger), "call", "manifest-init")
	)

	func() {
		r.rLock.Lock()
		defer r.rLock.Unlock()

		pkt.Flag = pkt.Flag.Set(codec.FlagJSON)
		pkt.Body = []byte(`{"name":"manifest","args":[],"type":"async"}`)

		r.highest++
		pkt.Req = r.highest
		r.reqs[pkt.Req] = &req

		req.id = pkt.Req
		req.sink.pkt.Req = pkt.Req
	}()
	if err != nil {
		dbg.Log("event", "request create failed", "err", err)
		return
	}

	dbg = log.With(dbg, "reqID", req.id)

	err = r.pkr.w.WritePacket(pkt)
	if err != nil {
		dbg.Log("event", "manifest request failed to send", "err", err)
		return
	}

	if !req.source.Next(ctx) {
		dbg.Log("event", "manifest request failed to read", "err", req.source.Err())
		return
	}

	r.manifest.mu.Lock()
	defer r.manifest.mu.Unlock()
	err = req.source.Reader(func(rd io.Reader) error {
		return json.NewDecoder(rd).Decode(&r.manifest.methods)
	})
	if err != nil {
		dbg.Log("event", "manifest request is invalid json", "err", err)
		return
	}

	r.manifest.missing = false
}

type manifestMap map[string]string

type manifestStruct struct {
	mu      *sync.Mutex
	missing bool
	methods manifestMap
}

func (ms *manifestStruct) Handled(m Method) (string, bool) {
	ms.mu.Lock()
	defer ms.mu.Unlock()
	// if the manifest is missing we assume the method is handled
	if ms.missing {
		return "", true
	}
	callType, yes := ms.methods[m.String()]
	return callType, yes
}

func (ms *manifestMap) UnmarshalJSON(bin []byte) error {
	var dullMap map[string]interface{}

	err := json.Unmarshal(bin, &dullMap)
	if err != nil {
		return err
	}

	methods := make(manifestMap)

	if err := recurseMap(methods, dullMap, nil); err != nil {
		return err
	}

	*ms = methods
	return nil
}

/* recurseMap iterates over and decends into a muxrpc manifest and creates a flat structure ala

"plugin.method1": "async",
"plugin.method2": "source",
"plugin.method3": "sink",
...

*/
func recurseMap(methods manifestMap, jsonMap map[string]interface{}, prefix Method) error {
	for k, iv := range jsonMap {
		switch tv := iv.(type) {
		case string: // string means that's a method
			m := append(prefix, k).String()
			methods[m] = tv

		case map[string]interface{}: // map means it's a plugin group
			err := recurseMap(methods, tv, append(prefix, k))
			if err != nil {
				return err
			}

		default:
			return fmt.Errorf("unhandled type in map: %T", iv)
		}
	}

	return nil
}
