module verseproj/scuttlegobridge

require (
	github.com/cryptix/go v1.5.0
	github.com/go-kit/kit v0.10.0
	github.com/mattn/go-sqlite3 v1.11.0
	github.com/pkg/errors v0.9.1
	go.cryptoscope.co/luigi v0.3.6-0.20200131144242-3256b54e72c8
	go.cryptoscope.co/margaret v0.1.7-0.20200519144842-7c553c9d3bce
	go.cryptoscope.co/muxrpc v1.5.4-0.20200501201518-aec356c21b48 // indirect
	go.cryptoscope.co/netwrap v0.1.1
	go.cryptoscope.co/ssb v0.0.0-20200520132839-d7485ad9385d
	go.mindeco.de/ssb-multiserver v0.0.0-20200302171328-987e421fadee
	golang.org/x/exp v0.0.0-20190912063710-ac5d2bfcbfe0 // indirect
	golang.org/x/net v0.0.0-20190909003024-a7b16738d86b // indirect
	golang.org/x/sync v0.0.0-20190911185100-cd5d95a43a6e
	gonum.org/v1/gonum v0.0.0-20190911200027-40d3308efe80 // indirect
	gonum.org/v1/netlib v0.0.0-20190331212654-76723241ea4e // indirect
)

go 1.14

replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24
