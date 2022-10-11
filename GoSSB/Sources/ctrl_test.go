package main

import (
	"github.com/stretchr/testify/require"
	"testing"
)

func TestMultiserverAddressToAddressAndRef(t *testing.T) {
	addr, ref, err := multiserverAddressToAddressAndRef("net:159.223.109.68:8008~shs:fs26fDL6HzqnHoc2Ekq40AD0ETdf/D3Ze5oAIiEn8sM=")
	require.NoError(t, err)
	require.Equal(t, "159.223.109.68:8008", addr.String())
	require.Equal(t, "@fs26fDL6HzqnHoc2Ekq40AD0ETdf/D3Ze5oAIiEn8sM=.ed25519", ref.String())
}
