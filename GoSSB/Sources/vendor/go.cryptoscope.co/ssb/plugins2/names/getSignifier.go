// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package names

import (
	"context"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/logging"
)

type hGetSignifier struct {
	as  aboutStore
	log logging.Interface
}

func (h hGetSignifier) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	ref, err := parseFeedRefFromArgs(req)
	if err != nil {
		return nil, err
	}

	ai, err := h.as.CollectedFor(ref)
	if err != nil {
		return nil, fmt.Errorf("do not have about for: %s: %w", ref.String(), err)

	}
	var name = ai.Name.Chosen
	if name == "" {
		for n := range ai.Name.Prescribed { // pick random name
			name = n
			break
		}
		if name == "" {
			name = ref.String()
		}
	}

	return name, nil
}
