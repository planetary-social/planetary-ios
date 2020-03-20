module go.cryptoscope.co/ssb

go 1.13

require (
	github.com/RoaringBitmap/roaring v0.4.21-0.20190925020156-96f2302555b6
	github.com/cryptix/go v1.5.0
	github.com/davecgh/go-spew v1.1.1
	github.com/dgraph-io/badger v2.0.0-rc2+incompatible
	github.com/dustin/go-humanize v1.0.0
	github.com/go-kit/kit v0.9.0
	github.com/hashicorp/go-multierror v1.0.0
	github.com/keks/nocomment v0.0.0-20181007001506-30c6dcb4a472
	github.com/keks/persist v0.0.0-20191006175951-43c124092b8b // indirect
	github.com/kylelemons/godebug v1.1.0
	github.com/libp2p/go-reuseport v0.0.1
	github.com/machinebox/progress v0.2.0 // indirect
	github.com/maxbrunsfeld/counterfeiter/v6 v6.2.2
	github.com/pkg/errors v0.9.1
	github.com/prometheus/client_golang v1.1.0
	github.com/shurcooL/go-goon v0.0.0-20170922171312-37c2f522c041
	github.com/stretchr/testify v1.5.1
	github.com/ugorji/go/codec v1.1.7
	go.cryptoscope.co/librarian v0.2.0
	go.cryptoscope.co/luigi v0.3.5
	go.cryptoscope.co/margaret v0.1.5
	go.cryptoscope.co/muxrpc v1.5.4-0.20191205134222-b1563255bffa
	go.cryptoscope.co/netwrap v0.1.1
	go.cryptoscope.co/secretstream v1.2.2-0.20200303151838-85cf020cfee6
	go.mindeco.de/ssb-gabbygrove v0.1.6
	go.mindeco.de/ssb-multiserver v0.0.0-20200302144839-6902de33e194
	golang.org/x/crypto v0.0.0-20200303113948-2939d6771b24
	golang.org/x/sync v0.0.0-20190911185100-cd5d95a43a6e
	golang.org/x/sys v0.0.0-20200302150141-5c8b2ff67527 // indirect
	golang.org/x/text v0.3.2
	gonum.org/v1/gonum v0.0.0-20190904110519-2065cbd6b42a
	gopkg.in/urfave/cli.v2 v2.0.0-20190806201727-b62605953717
	modernc.org/kv v1.0.0
)

// We need our internal/extra25519 since agl pulled his repo recently.
// Issue: https://github.com/cryptoscope/ssb/issues/44
// Ours uses a fork of x/crypto where edwards25519 is not an internal package,
// This seemed like the easiest change to port agl's extra25519 to use x/crypto
// Background: https://github.com/agl/ed25519/issues/27#issuecomment-591073699
// The branch in use: https://github.com/cryptix/golang_x_crypto/tree/non-internal-edwards
replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24
