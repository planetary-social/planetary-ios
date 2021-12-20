package legacyinvites

import (
	"context"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/muxrpc/v2"
)

// supplies create, use and other managment calls (maybe list and delete?)
type masterPlug struct {
	service *Service
}

func (p masterPlug) Name() string {
	return "invite"
}

func (p masterPlug) Method() muxrpc.Method {
	return muxrpc.Method{"invite"}
}

func (p masterPlug) Handler() muxrpc.Handler {
	return createHandler{
		service: p.service,
	}
}

type createHandler struct {
	service *Service
}

type CreateArguments struct {
	// how many times this invite should be useable
	Uses uint `json:"uses"`

	// a note to organize invites (also posted when used)
	Note string `json:"note,omitempty"`
}

func (createHandler) Handled(m muxrpc.Method) bool { return m.String() == "invite.create" }

func (h createHandler) HandleConnect(ctx context.Context, e muxrpc.Endpoint) {}

func (h createHandler) HandleCall(ctx context.Context, req *muxrpc.Request) {
	// parse passed arguments
	var args CreateArguments
	if err := json.Unmarshal(req.RawArgs, &args); err != nil {
		args.Uses = 1
	}

	if args.Uses == 0 {
		req.CloseWithError(fmt.Errorf("cant create invite with zero uses"))
		return
	}

	inv, err := h.service.Create(args.Uses, args.Note)
	if err != nil {
		req.CloseWithError(fmt.Errorf("failed to create invite"))
		return
	}

	req.Return(ctx, inv.String())
	h.service.logger.Log("invite", "created", "uses", args.Uses)
}
