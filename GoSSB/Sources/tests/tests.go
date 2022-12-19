package tests

import (
	"fmt"
	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/domain/identity"
	"github.com/planetary-social/scuttlego/service/domain/refs"
	"sync"
)

type TestKeys struct {
	keys map[string]identity.Private
	lock sync.Mutex
}

func NewTestKeys() *TestKeys {
	return &TestKeys{
		keys: make(map[string]identity.Private),
	}
}

func (k *TestKeys) CreateNamedKey(name string) error {
	k.lock.Lock()
	defer k.lock.Unlock()

	if _, ok := k.keys[name]; ok {
		return fmt.Errorf("key with name '%s' already exists", name)
	}

	iden, err := identity.NewPrivate()
	if err != nil {
		return errors.Wrap(err, "error creating a new key")
	}

	k.keys[name] = iden
	return nil
}

func (k *TestKeys) ListNamedKeys() map[string]refs.Identity {
	k.lock.Lock()
	defer k.lock.Unlock()

	result := make(map[string]refs.Identity)
	for name, iden := range k.keys {
		ref, err := refs.NewIdentityFromPublic(iden.Public())
		if err != nil {
			panic(err)
		}
		result[name] = ref
	}
	return result
}

func (k *TestKeys) GetNamedKey(name string) (identity.Private, error) {
	k.lock.Lock()
	defer k.lock.Unlock()

	iden, ok := k.keys[name]
	if !ok {
		return identity.Private{}, errors.New("key not found")
	}

	return iden, nil
}
