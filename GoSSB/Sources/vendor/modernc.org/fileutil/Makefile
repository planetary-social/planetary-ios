# Copyright (c) 2014 The fileutil authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

.PHONY: all clean editor build_all todo

all: editor
	go vet
	golint .
	go install
	make todo

editor:
	go fmt
	go test -i
	go test
	go build

PLATFORMS=darwin dragonfly freebsd linux netbsd openbsd plan9 solaris windows
ARCHITECTURES=386 amd64 arm arm64

build_all:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), $(shell export GOOS=$(GOOS); export GOARCH=$(GOARCH); go build -v -o /dev/null || go env)))

todo:
	@grep -n ^[[:space:]]*_[[:space:]]*=[[:space:]][[:alpha:]][[:alnum:]]* *.go || true
	@grep -n TODO *.go || true
	@grep -n BUG *.go || true
	@grep -n println *.go || true

clean:
	@go clean
	rm -f y.output
