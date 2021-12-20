PKGS := $(shell go list ./... | grep -v node_modules )


TESTFLAGS = -failfast -timeout 5m

# echo -en "\n        $(pkg)\r";
# this echo is just a trick to print the packge that is tested 
# and then returning the carriage to let the go test invocation print the result over the line
# so purly developer experience

.PHONY: test
test:
	$(foreach pkg, $(PKGS), echo -en "\n        $(pkg)\r"; LIBRARIAN_WRITEALL=0 go test $(pkg) || exit 1;)

.PHONY: racetest
racetest:
	$(foreach pkg, $(PKGS), echo -en "\n        $(pkg)\r"; LIBRARIAN_WRITEALL=0 go test $(TESTFLAGS) -race $(pkg) || exit 1;)

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
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o go-sbot ./cmd/go-sbot
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o sbotcli ./cmd/sbotcli
	GOOS=$(os) GOARCH=amd64 go build -v -i -trimpath $(LDFLAGS) -o gossb-truncate-log ./cmd/ssb-truncate-log
	tar cvf $(ARCHIVENAME) go-sbot sbotcli gossb-truncate-log
	rm go-sbot sbotcli gossb-truncate-log
	zstd -9 $(ARCHIVENAME)
	rm $(ARCHIVENAME)

.PHONY: release
release: windows linux darwin freebsd
