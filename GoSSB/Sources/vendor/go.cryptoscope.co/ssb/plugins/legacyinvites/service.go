package legacyinvites

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"sync"

	kitlog "github.com/go-kit/kit/log"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/muxrpc"
	"modernc.org/kv"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/invite"
	"go.cryptoscope.co/ssb/repo"
)

type Service struct {
	logger kitlog.Logger

	self    *ssb.FeedRef
	network ssb.Network

	publish    ssb.Publisher
	receiveLog margaret.Log

	mu sync.Mutex
	kv *kv.DB
}

func (s *Service) GuestHandler() muxrpc.Handler {
	return acceptHandler{
		service: s,
	}
}

func (s *Service) MasterPlugin() ssb.Plugin {
	return masterPlug{
		service: s,
	}
}

func (s *Service) Authorize(to *ssb.FeedRef) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	kvKey := []byte(to.StoredAddr())

	if err := s.kv.BeginTransaction(); err != nil {
		return err
	}

	has, err := s.kv.Get(nil, kvKey)
	if err != nil {
		s.kv.Rollback()
		return fmt.Errorf("invite/auth: failed get guest remote from KV (%w)", err)
	}
	if has == nil {
		s.kv.Rollback()
		return errors.New("not for us")
	}

	var st inviteState
	if err := json.Unmarshal(has, &st); err != nil {
		s.kv.Rollback()
		return fmt.Errorf("invite/auth: failed to probe new key (%w)", err)
	}

	if st.Used >= st.Uses {
		s.kv.Delete(kvKey)
		s.kv.Commit()
		return fmt.Errorf("invite/auth: invite depleeted")
	}

	return s.kv.Commit()
}

var _ ssb.Authorizer = (*Service)(nil)

func New(
	logger kitlog.Logger,
	r repo.Interface,
	self *ssb.FeedRef,
	nw ssb.Network,
	publish ssb.Publisher,
	rlog margaret.Log,
) (*Service, error) {
	kv, err := repo.OpenMKV(r.GetPath("plugin", "legacyinvites"))
	if err != nil {
		return nil, errors.Wrap(err, "failed to open key-value database")
	}

	return &Service{
		logger: logger,

		self:    self,
		network: nw,

		receiveLog: rlog,
		publish:    publish,

		kv: kv,
	}, nil
}

// Close closes the underlying key-value database
func (s Service) Close() error { return s.kv.Close() }

func (s Service) Create(uses uint, note string) (*invite.Token, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.kv.BeginTransaction(); err != nil {
		return nil, err
	}

	// roll seed
	var inv invite.Token
	var seedRef *ssb.FeedRef
	for {
		rand.Read(inv.Seed[:])

		inviteKeyPair, err := ssb.NewKeyPair(bytes.NewReader(inv.Seed[:]))
		if err != nil {
			s.kv.Rollback()
			return nil, fmt.Errorf("invite/create: generate seeded keypair (%w)", err)
		}

		has, err := s.kv.Get(nil, []byte(inviteKeyPair.Id.StoredAddr()))
		if err != nil {
			s.kv.Rollback()
			return nil, fmt.Errorf("invite/create: failed to probe new key (%w)", err)
		}
		if has == nil {
			seedRef = inviteKeyPair.Id
			break
		}
	}

	// store pub key with params (ties, note)
	st := inviteState{Used: 0}
	st.Uses = uses
	st.Note = note

	data, err := json.Marshal(st)
	if err != nil {
		s.kv.Rollback()
		return nil, fmt.Errorf("invite/create: failed to marshal state data (%w)", err)
	}

	err = s.kv.Set([]byte(seedRef.StoredAddr()), data)
	if err != nil {
		s.kv.Rollback()
		return nil, fmt.Errorf("invite/create: failed to store state data (%w)", err)
	}

	inv.Peer = *s.self
	// TODO: external host configuration?
	inv.Address = s.network.GetListenAddr()

	return &inv, s.kv.Commit()
}

type inviteState struct {
	createArguments

	Used uint // how many times this invite was used already
}
