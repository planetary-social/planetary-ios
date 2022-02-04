// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package groups

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
	"go.mindeco.de/log"
	"go.mindeco.de/log/level"

	"go.cryptoscope.co/ssb/private"
	refs "go.mindeco.de/ssb-refs"
)

type create struct {
	log log.Logger

	groups *private.Manager
}

func (h create) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []struct {
		Name string
	}
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return nil, fmt.Errorf("invalid argument on groups.create call: %w", err)
	}

	if len(args) != 1 {
		return nil, fmt.Errorf("expected one arg {name}")
	}
	a := args[0]

	cloaked, root, err := h.groups.Create(a.Name)
	if err != nil {
		return nil, err
	}

	level.Info(h.log).Log("event", "group created", "cloaked", cloaked.String())

	return struct {
		Group refs.MessageRef `json:"group_id"`
		Root  refs.MessageRef `json:"root"`
	}{cloaked, root}, err
}

type publishTo struct {
	log log.Logger

	groups *private.Manager
}

func (h publishTo) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []json.RawMessage
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return nil, fmt.Errorf("invalid argument on publishTo call: %w", err)
	}
	if len(args) != 2 {
		return nil, fmt.Errorf("expected two args [groupID, content]")
	}

	var groupID refs.MessageRef
	err := json.Unmarshal(args[0], &groupID)
	if err != nil {
		return nil, fmt.Errorf("groupID needs to be a valid message ref: %w", err)
	}

	if groupID.Algo() != refs.RefAlgoCloakedGroup {
		return nil, fmt.Errorf("groupID needs to be a cloaked message ref, not %s", groupID.Algo())
	}

	newMsg, err := h.groups.PublishTo(groupID, args[1])
	if err != nil {
		return nil, fmt.Errorf("failed to publish message to group")
	}

	return newMsg.String(), nil
}

type invite struct {
	log log.Logger

	groups *private.Manager
}

func (h invite) HandleAsync(ctx context.Context, req *muxrpc.Request) (interface{}, error) {
	var args []json.RawMessage
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		return nil, fmt.Errorf("invalid argument on publishTo call: %w", err)
	}
	if len(args) != 2 {
		return nil, fmt.Errorf("expected two args [groupID, content]")
	}

	var groupID refs.MessageRef
	err := json.Unmarshal(args[0], &groupID)
	if err != nil {
		return nil, fmt.Errorf("groupID needs to be a valid message ref: %w", err)
	}

	if groupID.Algo() != refs.RefAlgoCloakedGroup {
		return nil, fmt.Errorf("groupID needs to be a cloaked message ref, not %s", groupID.Algo())
	}

	var newMember refs.FeedRef
	err = json.Unmarshal(args[1], &newMember)
	if err != nil {
		return nil, fmt.Errorf("member needs to be a valid feed ID: %w", err)
	}

	newMsg, err := h.groups.AddMember(groupID, newMember, "")
	if err != nil {
		return nil, fmt.Errorf("failed to publish invite to group")
	}

	return newMsg.String(), nil
}
