module verseproj/scuttlegobridge

require (
	github.com/cryptix/go v1.5.0
	github.com/go-kit/kit v0.10.0
	github.com/mattn/go-sqlite3 v1.11.0
	github.com/pkg/errors v0.9.1
	github.com/stretchr/testify v1.7.0
	go.cryptoscope.co/luigi v0.3.6-0.20200131144242-3256b54e72c8
	go.cryptoscope.co/margaret v0.4.3
	go.cryptoscope.co/muxrpc/v2 v2.0.10
	go.cryptoscope.co/netwrap v0.1.1
	go.cryptoscope.co/ssb v0.2.2-0.20220218153308-74274366774e
	go.mindeco.de v1.12.0
	go.mindeco.de/ssb-multiserver v0.1.4-0.20210907140404-6f323e45e9f9
	go.mindeco.de/ssb-refs v0.4.2-0.20210908123826-f7ca13c14896
	golang.org/x/crypto v0.0.0-20210817164053-32db794688a5
	golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
)

require (
	filippo.io/edwards25519 v1.0.0-rc.1 // indirect
	github.com/DataDog/zstd v1.4.1 // indirect
	github.com/RoaringBitmap/roaring v0.6.1 // indirect
	github.com/cespare/xxhash v1.1.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/dgraph-io/badger/v3 v3.2011.1 // indirect
	github.com/dgraph-io/ristretto v0.0.4-0.20210122082011-bb5d392ed82d // indirect
	github.com/dgraph-io/sroar v0.0.0-20210524170324-9b164cbe6e02 // indirect
	github.com/dustin/go-humanize v1.0.0 // indirect
	github.com/go-logfmt/logfmt v0.5.0 // indirect
	github.com/golang/groupcache v0.0.0-20190702054246-869f871628b6 // indirect
	github.com/golang/protobuf v1.5.2 // indirect
	github.com/golang/snappy v0.0.3 // indirect
	github.com/google/flatbuffers v1.12.0 // indirect
	github.com/gorilla/websocket v1.4.1 // indirect
	github.com/hashicorp/errwrap v1.1.0 // indirect
	github.com/hashicorp/go-multierror v1.1.1 // indirect
	github.com/karrick/bufpool v1.2.0 // indirect
	github.com/karrick/gopool v1.2.2 // indirect
	github.com/keks/persist v0.0.0-20210520094901-9bdd97c1fad2 // indirect
	github.com/libp2p/go-reuseport v0.0.1 // indirect
	github.com/machinebox/progress v0.2.0 // indirect
	github.com/mschoch/smat v0.0.0-20160514031455-90eadee771ae // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/rs/cors v1.7.0 // indirect
	github.com/ssb-ngi-pointer/go-metafeed v1.1.1 // indirect
	github.com/ugorji/go/codec v1.2.6 // indirect
	github.com/willf/bitset v1.1.10 // indirect
	github.com/zeebo/bencode v1.0.0 // indirect
	go.cryptoscope.co/nocomment v0.0.0-20210520094614-fb744e81f810 // indirect
	go.cryptoscope.co/secretstream v1.2.9 // indirect
	go.mindeco.de/ssb-gabbygrove v0.2.1-0.20210907140645-35a659043bdd // indirect
	go.opencensus.io v0.22.5 // indirect
	golang.org/x/exp v0.0.0-20190912063710-ac5d2bfcbfe0 // indirect
	golang.org/x/net v0.0.0-20210525063256-abc453219eb5 // indirect
	golang.org/x/sys v0.0.0-20210525143221-35b2ab0089ea // indirect
	golang.org/x/text v0.3.6 // indirect
	gonum.org/v1/gonum v0.0.0-20190911200027-40d3308efe80 // indirect
	gonum.org/v1/netlib v0.0.0-20190331212654-76723241ea4e // indirect
	google.golang.org/protobuf v1.26.0 // indirect
	gopkg.in/yaml.v3 v3.0.0-20210107192922-496545a6307b // indirect
)

go 1.17

replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24

replace go.cryptoscope.co/ssb => github.com/planetary-social/ssb v0.2.2-0.20220502134602-5f4decb39d4a
