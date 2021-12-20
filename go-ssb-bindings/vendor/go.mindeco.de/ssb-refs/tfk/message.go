package tfk

import (
	"fmt"

	refs "go.mindeco.de/ssb-refs"
)

type Message struct{ value }

func MessageFromRef(r refs.MessageRef) (*Message, error) {
	var m Message
	m.tipe = TypeMessage

	m.key = make([]byte, 32)
	err := r.CopyHashTo(m.key)
	if err != nil {
		return nil, err
	}

	switch r.Algo() {
	case refs.RefAlgoMessageSSB1:
		m.format = FormatMessageSHA256
	case refs.RefAlgoCloakedGroup:
		m.format = FormatMessageCloaked
	case refs.RefAlgoMessageGabby:
		m.format = FormatMessageGabbyGrove
	case refs.RefAlgoMessageBendyButt:
		m.format = FormatMessageMetaFeed
	default:
		return nil, fmt.Errorf("format value: %q: %w", r.Algo(), ErrUnhandledFormat)
	}
	return &m, nil
}

// MarshalBinary returns the type-format-key encoding for a message.
func (msg *Message) MarshalBinary() ([]byte, error) {
	if msg.tipe != TypeMessage {
		return nil, ErrWrongType
	}
	if !IsValidMessageFormat(msg.format) {
		return nil, ErrUnhandledFormat
	}
	return msg.value.MarshalBinary()
}

// UnmarshalBinary takes some data, unboxes the t-f-k
// and does some validity checks to make sure it's an understood message reference.
func (msg *Message) UnmarshalBinary(data []byte) error {
	err := msg.value.UnmarshalBinary(data)
	if err != nil {
		msg.broken = true
		return err
	}

	if msg.tipe != TypeMessage {
		msg.broken = true
		return ErrWrongType
	}

	if !IsValidMessageFormat(msg.format) {
		msg.broken = true
		return ErrUnhandledFormat
	}

	var wantedKeyLen int = 32
	switch msg.format {
	case FormatMessageBamboo:
		wantedKeyLen = 64
	}

	if n := len(msg.key); n != wantedKeyLen {
		msg.broken = true
		return fmt.Errorf("ssb/tfk/message: unexpected key length: %d: %w", n, ErrTooShort)
	}
	return nil
}

// Message retruns the ssb-ref type after a successfull unmarshal.
// It returns a new copy to discourage tampering with the internal values of this reference.
func (msg Message) Message() (refs.MessageRef, error) {
	if msg.broken {
		return refs.MessageRef{}, fmt.Errorf("tfk: broken message ref")
	}
	var algo refs.RefAlgo
	switch msg.format {
	case FormatMessageSHA256:
		algo = refs.RefAlgoMessageSSB1
	case FormatMessageCloaked:
		algo = refs.RefAlgoCloakedGroup
	case FormatMessageGabbyGrove:
		algo = refs.RefAlgoMessageGabby
	case FormatMessageMetaFeed:
		algo = refs.RefAlgoMessageBendyButt
	case FormatMessageBamboo:
		algo = refs.RefAlgoMessageBamboo
	default:
		return refs.MessageRef{}, fmt.Errorf("format value: %x: %w", msg.format, ErrUnhandledFormat)

	}

	return refs.NewMessageRefFromBytes(msg.key, algo)
}
