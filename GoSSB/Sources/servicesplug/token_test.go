package servicesplug

import (
	"testing"
	"time"

	"github.com/cryptix/go/encodedTime"

	"github.com/stretchr/testify/assert"
)

func TestExpired(t *testing.T) {
	a := assert.New(t)

	tok := Token{}
	a.True(tok.Expired())

	tok = Token{Token: "fooo"}
	a.True(tok.Expired())

	tok = Token{Token: "fooo", Expires: encodedTime.Millisecs(time.Now().Add(time.Hour * 10))}
	a.False(tok.Expired())
}
