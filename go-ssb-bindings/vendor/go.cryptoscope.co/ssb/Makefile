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

.PHONY: $(PLATFORMS)
$(PLATFORMS):
	mkdir -p release/$(os)
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o release/$(os)/go-sbot-$(VERSION)-amd64 ./cmd/go-sbot
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o release/$(os)/sbotcli-$(VERSION)-amd64 ./cmd/sbotcli

.PHONY: release
release: windows linux darwin freebsd
