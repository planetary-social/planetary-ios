module verseproj/scuttlegobridge

require (
	github.com/cryptix/go v1.5.0
	github.com/go-kit/kit v0.10.0
	github.com/mattn/go-sqlite3 v1.11.0
	github.com/pkg/errors v0.9.1
	github.com/stretchr/testify v1.7.0
	go.cryptoscope.co/luigi v0.3.6-0.20200131144242-3256b54e72c8
	go.cryptoscope.co/margaret v0.4.0
	go.cryptoscope.co/muxrpc/v2 v2.0.10
	go.cryptoscope.co/netwrap v0.1.1
	go.cryptoscope.co/ssb v0.2.2-0.20220120085157-a846f1659c87
	go.mindeco.de v1.12.0
	go.mindeco.de/ssb-multiserver v0.1.4-0.20210907140404-6f323e45e9f9
	go.mindeco.de/ssb-refs v0.4.2-0.20210908123826-f7ca13c14896
	golang.org/x/crypto v0.0.0-20210817164053-32db794688a5
	golang.org/x/exp v0.0.0-20190912063710-ac5d2bfcbfe0 // indirect
	golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
	gonum.org/v1/gonum v0.0.0-20190911200027-40d3308efe80 // indirect
	gonum.org/v1/netlib v0.0.0-20190331212654-76723241ea4e // indirect
)

go 1.14

replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24
