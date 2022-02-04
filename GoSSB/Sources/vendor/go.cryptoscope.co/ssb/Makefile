# SPDX-FileCopyrightText: 2021 The Go-SSB Authors
# SPDX-License-Identifier: MIT

PKGS := $(shell go list ./... | grep -v node_modules )


TESTFLAGS = -failfast -timeout 5m


ZIPPER := zstd -9
ifeq (, $(shell which zstd))
ZIPPER := gzip
endif

# echo -en "\n        $(pkg)\r";
# this echo is just a trick to print the packge that is tested 
# and then returning the carriage to let the go test invocation print the result over the line
# so purly developer experience

.PHONY: test
test:
	$(foreach pkg, $(PKGS), echo -en "\n        $(pkg)\r"; LIBRARIAN_WRITEALL=0 go test $(TESTFLAGS) $(pkg) || exit 1;)

.PHONY: racetest
racetest:
	$(foreach pkg, $(PKGS), echo -en "\n        $(pkg)\r"; LIBRARIAN_WRITEALL=0 go test $(TESTFLAGS) -race $(pkg) || exit 1;)

VERSION = $(shell git describe --tags --exact-match)
ifeq ($(VERSION),)
	VERSION = $(shell git rev-parse --short HEAD)
endif
BUILD=$(shell date +%FT%T%z)

LDFLAGS=-ldflags "-w -s -X main.Version=${VERSION} -X main.Build=${BUILD}"

PLATFORMS := windows-amd64 windows-arm64 linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 freebsd-amd64
os = $(word 1,$(subst -, ,$@))
arch = $(word 2,$(subst -, ,$@))

ARCHIVENAME=release/$(os)-$(arch)-$(VERSION).tar

.PHONY: $(PLATFORMS)

$(PLATFORMS):
	GOOS=$(os) GOARCH=$(arch) go build -v -i -trimpath $(LDFLAGS) -o go-sbot ./cmd/go-sbot
	GOOS=$(os) GOARCH=$(arch) go build -v -i -trimpath $(LDFLAGS) -o sbotcli ./cmd/sbotcli
	GOOS=$(os) GOARCH=$(arch) go build -v -i -trimpath $(LDFLAGS) -o gossb-truncate-log ./cmd/ssb-truncate-log
	GOOS=$(os) GOARCH=$(arch) go build -v -i -trimpath $(LDFLAGS) -o ssb-offset-converter ./cmd/ssb-offset-converter
	tar cvf $(ARCHIVENAME) go-sbot sbotcli gossb-truncate-log ssb-offset-converter 
	rm go-sbot sbotcli gossb-truncate-log ssb-offset-converter
	$(ZIPPER) $(ARCHIVENAME)
	rm $(ARCHIVENAME) || true

.PHONY: darwin-universal
darwin-universal:
ifeq (, $(shell which lipo))
	$(info darwin-universal can only be made if lipo binary is available.)
else
	GOOS=darwin GOARCH=arm64 go build -v -i -trimpath $(LDFLAGS) -o go-sbot-arm64 ./cmd/go-sbot
	GOOS=darwin GOARCH=arm64 go build -v -i -trimpath $(LDFLAGS) -o sbotcli-arm64 ./cmd/sbotcli
	GOOS=darwin GOARCH=arm64 go build -v -i -trimpath $(LDFLAGS) -o gossb-truncate-log-arm64 ./cmd/ssb-truncate-log
	GOOS=darwin GOARCH=arm64 go build -v -i -trimpath $(LDFLAGS) -o ssb-offset-converter-arm64 ./cmd/ssb-offset-converter

	GOOS=darwin GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o go-sbot-amd64 ./cmd/go-sbot
	GOOS=darwin GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o sbotcli-amd64 ./cmd/sbotcli
	GOOS=darwin GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o gossb-truncate-log-amd64 ./cmd/ssb-truncate-log
	GOOS=darwin GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o ssb-offset-converter-amd64 ./cmd/ssb-offset-converter

	lipo -create go-sbot-arm64 go-sbot-amd64 -o go-sbot
	lipo -create sbotcli-arm64 sbotcli-amd64 -o sbotcli
	lipo -create gossb-truncate-log-arm64 gossb-truncate-log-amd64 -o gossb-truncate-log
	lipo -create ssb-offset-converter-arm64 ssb-offset-converter-amd64 -o ssb-offset-converter 

	tar cvf $(ARCHIVENAME) go-sbot sbotcli gossb-truncate-log ssb-offset-converter 
	rm go-sbot sbotcli gossb-truncate-log ssb-offset-converter
	$(ZIPPER) $(ARCHIVENAME)
	rm $(ARCHIVENAME) || true
endif


.PHONY: release
release: windows-amd64 windows-arm64 linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 darwin-universal freebsd-amd64
