package tests

import (
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestTestKeys_ListNamedKeys(t *testing.T) {
	tk := NewTestKeys(NewStorage(someDirectory(t)))

	name1 := "name1"
	name2 := "name2"

	err := tk.CreateNamedKey(name1)
	require.NoError(t, err)

	err = tk.CreateNamedKey(name2)
	require.NoError(t, err)

	keys, err := tk.ListNamedKeys()
	require.NoError(t, err)

	require.Len(t, keys, 2)
	for k, v := range keys {
		require.NotEmpty(t, k)
		require.False(t, v.IsZero())
	}
}

func TestStorage_List(t *testing.T) {
	s := NewStorage(someDirectory(t))

	name1 := "name1"
	name2 := "name2"

	err := s.Put(name1, nil)
	require.NoError(t, err)

	err = s.Put(name2, nil)
	require.NoError(t, err)

	names, err := s.List()
	require.NoError(t, err)

	require.Equal(t,
		[]string{
			name1,
			name2,
		},
		names,
	)
}

func someDirectory(t *testing.T) string {
	temp, err := os.MkdirTemp("", "go_tests")
	require.NoError(t, err)

	t.Cleanup(func() {
		if err := os.RemoveAll(temp); err != nil {
			t.Log(err)
		}
	})

	return temp
}
