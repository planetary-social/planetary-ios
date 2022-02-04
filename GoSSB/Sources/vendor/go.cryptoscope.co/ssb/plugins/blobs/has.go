// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package blobs

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/blobstore"
	refs "go.mindeco.de/ssb-refs"
)

type hasHandler struct {
	bs  ssb.BlobStore
	log logging.Interface
}

func (h hasHandler) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var blobRef refs.BlobRef

	err := json.Unmarshal(req.RawArgs, &blobRef)

	if err != nil { // assume list of refs
		var blobRefs []refs.BlobRef
		err := json.Unmarshal(req.RawArgs, &blobRefs)
		if err != nil {
			return nil, fmt.Errorf("bad request - unhandled type %s", err)
		}
		var has = make([]bool, len(blobRefs))

		for k, blobRef := range blobRefs {
			_, err = h.bs.Size(blobRef)

			has[k] = true

			if err == blobstore.ErrNoSuchBlob {
				has[k] = false
			} else if err != nil {
				err = fmt.Errorf("error looking up blob: %w", err)
				return nil, err

			}

		}
		return has, nil

	}

	_, err = h.bs.Size(blobRef)

	has := true

	if err == blobstore.ErrNoSuchBlob {
		has = false
	} else if err != nil {
		err = fmt.Errorf("error looking up blob: %w", err)
		return nil, err
	}
	return has, nil
}
