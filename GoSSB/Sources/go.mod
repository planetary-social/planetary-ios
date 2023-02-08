module verseproj/scuttlegobridge

require (
	github.com/boreq/errors v0.1.0
	github.com/dgraph-io/badger/v3 v3.2103.5
	github.com/go-kit/kit v0.12.0
	github.com/pkg/errors v0.9.1
	github.com/planetary-social/scuttlego v0.0.0-20230208142843-b3aac191585e
	github.com/sirupsen/logrus v1.8.1
	github.com/stretchr/testify v1.8.1
	go.cryptoscope.co/ssb v0.2.2-0.20220218153308-74274366774e
	go.mindeco.de/ssb-multiserver v0.1.4-0.20210907140404-6f323e45e9f9
	go.mindeco.de/ssb-refs v0.4.2-0.20210908123826-f7ca13c14896
)

require (
	filippo.io/edwards25519 v1.0.0 // indirect
	github.com/cespare/xxhash v1.1.0 // indirect
	github.com/cespare/xxhash/v2 v2.1.2 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/dgraph-io/ristretto v0.1.1 // indirect
	github.com/dgraph-io/sroar v0.0.0-20220527172339-b92b7eaaf6e0 // indirect
	github.com/dustin/go-humanize v1.0.0 // indirect
	github.com/go-kit/log v0.2.0 // indirect
	github.com/go-logfmt/logfmt v0.5.1 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/glog v1.0.0 // indirect
	github.com/golang/groupcache v0.0.0-20210331224755-41bb18bfe9da // indirect
	github.com/golang/protobuf v1.5.2 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/google/flatbuffers v22.10.26+incompatible // indirect
	github.com/google/go-cmp v0.5.8 // indirect
	github.com/google/wire v0.5.0 // indirect
	github.com/gorilla/websocket v1.5.0 // indirect
	github.com/hashicorp/errwrap v1.1.0 // indirect
	github.com/hashicorp/go-multierror v1.1.1 // indirect
	github.com/karrick/bufpool v1.2.0 // indirect
	github.com/karrick/gopool v1.2.2 // indirect
	github.com/keks/persist v0.0.0-20210520094901-9bdd97c1fad2 // indirect
	github.com/klauspost/compress v1.15.12 // indirect
	github.com/libp2p/go-reuseport v0.2.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/ssb-ngi-pointer/go-metafeed v1.1.1 // indirect
	github.com/ssbc/go-gabbygrove v0.0.0-20221025092911-c274a44c3523 // indirect
	github.com/ssbc/go-luigi v0.3.7-0.20230119190114-bd28e676fa99 // indirect
	github.com/ssbc/go-metafeed v1.1.3-0.20221019090205-458925e39156 // indirect
	github.com/ssbc/go-muxrpc/v2 v2.0.14-0.20221111190521-10382533750c // indirect
	github.com/ssbc/go-netwrap v0.1.5-0.20221019160355-cd323bb2e29d // indirect
	github.com/ssbc/go-secretstream v1.2.11-0.20221111164233-4b41f899f844 // indirect
	github.com/ssbc/go-ssb v0.2.2-0.20230201061938-55f48949535c // indirect
	github.com/ssbc/go-ssb-multiserver v0.1.5-0.20221019203850-917ae0e23d57 // indirect
	github.com/ssbc/go-ssb-refs v0.5.2-0.20221019090322-8b558c2f31de // indirect
	github.com/ssbc/margaret v0.4.4-0.20230125145533-1439efe21dc4 // indirect
	github.com/ugorji/go/codec v1.2.8 // indirect
	github.com/zeebo/bencode v1.0.0 // indirect
	go.cryptoscope.co/luigi v0.3.6-0.20200131144242-3256b54e72c8 // indirect
	go.cryptoscope.co/margaret v0.4.3 // indirect
	go.cryptoscope.co/muxrpc/v2 v2.0.10 // indirect
	go.cryptoscope.co/netwrap v0.1.1 // indirect
	go.cryptoscope.co/nocomment v0.0.0-20210520094614-fb744e81f810 // indirect
	go.cryptoscope.co/secretstream v1.2.10 // indirect
	go.mindeco.de v1.12.0 // indirect
	go.opencensus.io v0.23.0 // indirect
	golang.org/x/crypto v0.4.0 // indirect
	golang.org/x/net v0.5.0 // indirect
	golang.org/x/sys v0.5.0 // indirect
	golang.org/x/text v0.6.0 // indirect
	google.golang.org/protobuf v1.28.1 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

go 1.19

replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24

replace go.mindeco.de => github.com/planetary-social/go-toolbelt v0.0.0-20220509144343-0f7ad206c2b7
