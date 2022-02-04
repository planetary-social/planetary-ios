// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package private

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	librarian "go.cryptoscope.co/margaret/indexes"
	"go.cryptoscope.co/ssb/internal/mutil"
	refs "go.mindeco.de/ssb-refs"
)

func (mgr *Manager) getTangleState(root refs.MessageRef, tname string) refs.TanglePoint {
	var h = make([]byte, 32)
	root.CopyHashTo(h)
	addr := librarian.Addr(append([]byte("v2:"+tname+":"), h...))
	thandle, err := mgr.tangles.Get(addr)
	if err != nil {
		return refs.TanglePoint{Root: &root, Previous: []refs.MessageRef{root}}
	}

	heads, err := mgr.getLooseEnds(thandle, tname)
	if err != nil {
		panic(err)
	}
	if len(heads) == 0 {
		heads = refs.MessageRefs{root}
	}
	return refs.TanglePoint{Root: &root, Previous: heads}
}

func (mgr *Manager) getLooseEnds(l margaret.Log, tname string) (refs.MessageRefs, error) {
	src, err := mutil.Indirect(mgr.receiveLog, l).Query()
	if err != nil {
		return nil, err
	}
	todoCtx := context.TODO()
	var tps []refs.TangledPost
	for {
		src, err := src.Next(todoCtx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			return nil, err
		}

		msg, ok := src.(refs.Message)
		if !ok {
			return nil, fmt.Errorf("not a mesg %T", src)
		}

		content, err := mgr.DecryptBox2Message(msg)
		if err != nil {
			// fmt.Println("not for us?", err) // or deleted key?
			continue
		}

		// find tangles
		var p struct {
			Tangles refs.Tangles `json:"tangles"`
		}
		err = json.Unmarshal(content, &p)
		if err != nil {
			return nil, err
		}

		tps = append(tps, refs.TangledPost(tangledPost{MessageRef: msg.Key(), Tangles: p.Tangles}))
	}

	sorter := refs.ByPrevious{Items: tps, TangleName: tname}
	// sort.Sort(sorter) // not required for Heads()

	h := sorter.Heads()
	return h, nil
}

type tangledPost struct {
	refs.MessageRef

	refs.Tangles
}

func (tm tangledPost) Key() refs.MessageRef {
	return tm.MessageRef
}

func (tm tangledPost) Tangle(name string) (*refs.MessageRef, refs.MessageRefs) {
	tp, has := tm.Tangles[name]
	if !has {
		return nil, nil
	}

	return tp.Root, tp.Previous
}
