package tests

import (
	"io/fs"
	"os"
	"path/filepath"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/domain/identity"
	"github.com/planetary-social/scuttlego/service/domain/refs"
)

const everyone = 0777

type TestKeys struct {
	storage *Storage
}

func NewTestKeys(storage *Storage) *TestKeys {
	return &TestKeys{
		storage: storage,
	}
}

func (k *TestKeys) CreateNamedKey(name string) error {
	iden, err := identity.NewPrivate()
	if err != nil {
		return errors.Wrap(err, "error creating a new key")
	}

	if err := k.storage.Put(name, iden.PrivateKey()); err != nil {
		return errors.Wrap(err, "error storing the key")
	}

	return nil
}

func (k *TestKeys) ListNamedKeys() (map[string]refs.Identity, error) {
	names, err := k.storage.List()
	if err != nil {
		return nil, errors.Wrap(err, "error listing keys")
	}

	result := make(map[string]refs.Identity)

	for _, name := range names {
		iden, err := k.load(name)
		if err != nil {
			return nil, errors.Wrap(err, "error loading a key")
		}

		ref, err := refs.NewIdentityFromPublic(iden.Public())
		if err != nil {
			return nil, errors.Wrap(err, "error creating a ref")
		}
		result[name] = ref
	}

	return result, nil
}

func (k *TestKeys) GetNamedKey(name string) (identity.Private, error) {
	return k.load(name)
}

func (k *TestKeys) load(name string) (identity.Private, error) {
	b, err := k.storage.Get(name)
	if err != nil {
		return identity.Private{}, errors.Wrap(err, "error retrieving from storage")
	}

	iden, err := identity.NewPrivateFromBytes(b)
	if err != nil {
		return identity.Private{}, errors.Wrap(err, "error creating an identity")
	}

	return iden, nil
}

type Storage struct {
	directory string
}

func NewStorage(directory string) *Storage {
	return &Storage{directory: directory}
}

func (s *Storage) Put(name string, data []byte) error {
	if err := os.MkdirAll(s.directory, everyone); err != nil {
		return errors.Wrap(err, "error creating the directory")
	}

	return os.WriteFile(s.filepath(name), data, everyone)
}

func (s *Storage) Get(name string) ([]byte, error) {
	b, err := os.ReadFile(s.filepath(name))
	if err != nil {
		return nil, errors.Wrap(err, "error reading file")
	}

	return b, nil
}

func (s *Storage) List() ([]string, error) {
	var names []string
	if err := filepath.Walk(s.directory, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return errors.Wrap(err, "received an error")
		}

		if !info.IsDir() {
			names = append(names, info.Name())
		}

		return nil
	}); err != nil {
		return nil, errors.Wrap(err, "walk error")
	}

	return names, nil
}

func (s *Storage) filepath(name string) string {
	return filepath.Join(s.directory, name)
}
