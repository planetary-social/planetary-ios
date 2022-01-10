package legacyinvites

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/pkg/errors"
	"go.cryptoscope.co/muxrpc"

	"go.cryptoscope.co/ssb"
)

type acceptHandler struct {
	service *Service
}

func (h acceptHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (h acceptHandler) HandleCall(ctx context.Context, req *muxrpc.Request, edp muxrpc.Endpoint) {
	h.service.mu.Lock()
	defer h.service.mu.Unlock()
	if req.Method.String() != "invite.use" {
		req.CloseWithError(fmt.Errorf("unknown method"))
		return
	}

	// parse passed arguments
	var args []struct {
		Feed *ssb.FeedRef `json:"feed"`
	}
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		fmt.Println("accept:", string(req.RawArgs))
		req.CloseWithError(fmt.Errorf("invalid arguments (%w)", err))
		return
	}

	if len(args) != 1 {
		req.CloseWithError(fmt.Errorf("invalid argument count"))
	}
	arg := args[0]

	// lookup guest key
	if err := h.service.kv.BeginTransaction(); err != nil {
		req.CloseWithError(err)
		return
	}

	guestRef, err := ssb.GetFeedRefFromAddr(edp.Remote())
	if err != nil {
		req.CloseWithError(errors.Wrap(err, "no guest ref!?"))
		return
	}

	kvKey := []byte(guestRef.StoredAddr())

	has, err := h.service.kv.Get(nil, kvKey)
	if err != nil {
		h.service.kv.Rollback()
		err = fmt.Errorf("invite/kv: failed get guest remote from KV (%w)", err)
		req.CloseWithError(err)
		return
	}
	if has == nil {
		h.service.kv.Rollback()
		err = errors.New("not for us")
		req.CloseWithError(err)
		return
	}

	var st inviteState
	if err := json.Unmarshal(has, &st); err != nil {
		h.service.kv.Rollback()
		err = fmt.Errorf("invite/kv: failed to probe new key (%w)", err)
		req.CloseWithError(err)
		return
	}

	if st.Used >= st.Uses {
		h.service.kv.Delete(kvKey)
		h.service.kv.Commit()
		err = fmt.Errorf("invite/kv: invite depleeted")
		req.CloseWithError(err)
		return
	}

	// count uses
	st.Used++

	updatedState, err := json.Marshal(st)
	if err != nil {
		h.service.kv.Rollback()
		err = fmt.Errorf("invite/kv: failed marshal updated state data (%w)", err)
		req.CloseWithError(err)
		return
	}
	err = h.service.kv.Set(kvKey, updatedState)
	if err != nil {
		h.service.kv.Rollback()
		err = fmt.Errorf("invite/kv: failed save updated state data (%w)", err)
		req.CloseWithError(err)
		return
	}
	err = h.service.kv.Commit()
	if err != nil {
		h.service.kv.Rollback()
		err = fmt.Errorf("invite/kv: failed to commit kv transaction (%w)", err)
		req.CloseWithError(err)
		return
	}

	// publish follow for requested Feed
	var contactWithNote struct {
		*ssb.Contact
		Note string `json:"note,omitempty"`
		Pub  bool   `json:"pub"`
	}
	contactWithNote.Pub = true
	contactWithNote.Note = st.Note
	contactWithNote.Contact = ssb.NewContactFollow(arg.Feed)

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
	req.Return(ctx, msgv)

	h.service.logger.Log("invite", "used")
}
