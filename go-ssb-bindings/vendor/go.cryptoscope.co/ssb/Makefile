PKGS := $(shell go list ./... | grep -v /vendor | grep -v node_modules)

.PHONY: test
test:
	go test -failfast -race -timeout 2m $(PKGS)

VERSION = $(shell git describe --tags --exact-match)
ifeq ($(VERSION),)
	VERSION = $(shell git rev-parse --short HEAD)
endif
BUILD=$(shell date +%FT%T%z)

LDFLAGS=-ldflags "-w -s -X main.Version=${VERSION} -X main.Build=${BUILD}"

PLATFORMS := windows linux darwin freebsd
os = $(word 1, $@)

ARCHIVENAME=release/$(os)-$(VERSION).tar

.PHONY: $(PLATFORMS)
$(PLATFORMS):
	mkdir -p release/$(os)
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o go-sbot ./cmd/go-sbot
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o sbotcli ./cmd/sbotcli
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o gossb-truncate-log ./cmd/ssb-truncate-log
	tar cvf $(ARCHIVENAME) go-sbot sbotcli gossb-truncate-log
	rm go-sbot sbotcli gossb-truncate-log
	zstd -9 $(ARCHIVENAME)
	rm $(ARCHIVENAME)

.PHONY: release
release: windows linux darwin freebsd
