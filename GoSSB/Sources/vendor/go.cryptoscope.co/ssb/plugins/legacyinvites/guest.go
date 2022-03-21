// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package legacyinvites

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/dgraph-io/badger/v3"
	"go.cryptoscope.co/muxrpc/v2"

	"go.cryptoscope.co/ssb"
	refs "go.mindeco.de/ssb-refs"
)

type acceptHandler struct {
	service *Service
}

func (acceptHandler) Handled(m muxrpc.Method) bool { return m.String() == "invite.use" }

func (h acceptHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

// TODO: re-write as typemux.AsyncFunc
func (h acceptHandler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	// parse passed arguments
	var args []struct {
		Feed refs.FeedRef `json:"feed"`
	}
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		req.CloseWithError(fmt.Errorf("invalid arguments (%w)", err))
		return
	}

	if len(args) != 1 {
		req.CloseWithError(fmt.Errorf("invalid argument count"))
	}
	arg := args[0]

	guestRef, err := ssb.GetFeedRefFromAddr(req.RemoteAddr())
	if err != nil {
		req.CloseWithError(fmt.Errorf("no guest ref!?: %w", err))
		return
	}

	// lookup guest key
	var st inviteState
	kvKey := append(dbKeyPrefix, guestRef.PubKey()...)
	err = h.service.kv.Update(func(txn *badger.Txn) error {
		has, err := txn.Get(kvKey)
		if err != nil {
			return fmt.Errorf("invite/kv: failed get guest remote from KV (%w)", err)
		}

		err = has.Value(func(val []byte) error {
			return json.Unmarshal(val, &st)
		})
		if err != nil {
			return fmt.Errorf("invite/kv: failed to probe new key (%w)", err)
		}

		if st.Used >= st.Uses {
			txn.Delete(kvKey)
			return fmt.Errorf("invite/kv: invite depleted")
		}

		// count uses
		st.Used++

		updatedState, err := json.Marshal(st)
		if err != nil {
			return fmt.Errorf("invite/kv: failed marshal updated state data (%w)", err)
		}

		err = txn.Set(kvKey, updatedState)
		if err != nil {
			return fmt.Errorf("invite/kv: failed save updated state data (%w)", err)
		}

		return nil
	})
	if err != nil {
		req.CloseWithError(err)
		return
	}

	// publish follow for requested Feed
	var contactWithNote struct {
		refs.Contact
		Note string `json:"note,omitempty"`
		Pub  bool   `json:"pub"`
	}
	contactWithNote.Pub = true
	contactWithNote.Note = st.Note
	contactWithNote.Contact = refs.NewContactFollow(arg.Feed)

	seq, err := h.service.publish.Append(contactWithNote)
	if err != nil {
		req.CloseWithError(fmt.Errorf("invite/accept: failed to publish invite accept (%w)", err))
		return
	}

	msgv, err := h.service.receiveLog.Get(seq)
	if err != nil {
		req.CloseWithError(fmt.Errorf("invite/accept: failed to publish invite accept (%w)", err))
		return
	}

	h.service.replicator.Replicate(arg.Feed)

	req.Return(ctx, msgv)

	h.service.logger.Log("invite", "used")
}
