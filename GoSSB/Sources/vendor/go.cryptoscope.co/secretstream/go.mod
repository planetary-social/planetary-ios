module go.cryptoscope.co/secretstream

require (
	github.com/cryptix/go v1.5.0
	github.com/go-kit/kit v0.9.0 // indirect
	github.com/stretchr/testify v1.4.0
	go.cryptoscope.co/netwrap v0.1.0
	golang.org/x/crypto v0.0.0-20200303113948-2939d6771b24
	golang.org/x/sys v0.0.0-20191007154456-ef33b2fb2c41 // indirect
)

go 1.13

// We need our internal/extra25519 since agl pulled his repo recently.
// Issue: https://github.com/cryptoscope/ssb/issues/44
// Ours uses a fork of x/crypto where edwards25519 is not an internal package,
// This seemed like the easiest change to port agl's extra25519 to use x/crypto
// Background: https://github.com/agl/ed25519/issues/27#issuecomment-591073699
// The branch in use: https://github.com/cryptix/golang_x_crypto/tree/non-internal-edwards
replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24
