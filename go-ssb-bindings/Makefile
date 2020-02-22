# Copyright (C) 2019 Henry Bubert <cryptix@riseup.net>. All Rights Reserved.

IPHONEOS_DEPLOYMENT_TARGET ?= 10.4

# architecture and SDK paths

CFLAGS := $(if $(DEPLOYMENT_TARGET_CLANG_FLAG_NAME),-$(DEPLOYMENT_TARGET_CLANG_FLAG_NAME)=$($(DEPLOYMENT_TARGET_CLANG_ENV_NAME)),) -Wno-unused-command-line-argument

ARCHS_SIM ?= x86_64
PLATFORM_SIM = iPhoneSimulator
SDKROOT_SIM = $(shell xcode-select -print-path)/Platforms/$(PLATFORM_SIM).platform/Developer/SDKs/$(PLATFORM_SIM)$(IPHONEOS_SDK).sdk
EXTRA_CFLAGS_SIM += -pipe -fvisibility=hidden $(INCLUDE) -isysroot $(SDKROOT_SIM)
EXTRA_CFLAGS_SIM += -D__IPHONE_OS_VERSION_MIN_REQUIRED=20000
CFLAGS_SIM = $(CFLAGS) $(EXTRA_CFLAGS_SIM)

ARCHS_PHONE ?= arm64
PLATFORM_PHONE = iPhoneOS
SDKROOT_PHONE = $(shell xcode-select -print-path)/Platforms/$(PLATFORM_PHONE).platform/Developer/SDKs/$(PLATFORM_PHONE)$(IPHONEOS_SDK).sdk
EXTRA_CFLAGS_PHONE += -pipe -fvisibility=hidden $(INCLUDE) -isysroot $(SDKROOT_PHONE)
EXTRA_CFLAGS_PHONE += -miphoneos-version-min=$(IPHONEOS_DEPLOYMENT_TARGET)
CFLAGS_PHONE = $(CFLAGS) $(EXTRA_CFLAGS_PHONE)

CONFIGURATION_BUILD_DIR ?= $(CURDIR)/out
CONFIGURATION_TEMP_DIR ?= $(CURDIR)/.tmp

# compiler and linker
export CC ?= clang
LIPO ?= lipo
# path output
DESTDIR ?= $(CONFIGURATION_BUILD_DIR)
BUILDDIR ?= $(CONFIGURATION_TEMP_DIR)/go-ssb-bridge

# go architecture and platform settings
GOARCH_arm64 := arm64
GOARCHSIM_x86_64 := amd64
export GOOS := darwin
export CGO_ENABLED := 1

# main build targets
build: $(DESTDIR)/libssb-go.a

GOROOT ?= $(TEMP_ROOT)/.goroot
export GOPATH := $(BUILDDIR)/gopath
export PATH := $(GOROOT)/bin:$(PATH)

GO := $(GOROOT)/bin/go

GOEXTRAFLAGS=-trimpath -mod=vendor
GOBUILDTAGS = ios
# ifdef DEBUG <  this var is not set when the Build Step script is called  by Xcode
# ifeq ($(ENABLE_TESTABILITY),YES) < also works, not sure what the difference is
ifeq ($(CONFIGURATION),Debug)
    GOBUILDTAGS += testing
else
    GOEXTRAFLAGS += -ldflags="-s -w"
endif
GOEXTRAFLAGS += -tags "$(GOBUILDTAGS)"

$(shell test "$$(cat "$(BUILDDIR)/.gobuildversion" 2>/dev/null)" = "$(GOBUILDVERSION_CURRENT)" || rm -f "$(DESTDIR)/libssb-go.a")

# this builds multiple lib.a files for different ARCHS_PHONE
define libssb-go-a
$(BUILDDIR)/libssb-go-$(1).a: *.go
	CGO_CFLAGS="$(CFLAGS_PHONE) -arch $(ARCH)" \
	CGO_LDFLAGS="$(CFLAGS_PHONE) -arch $(ARCH)" \
	GOARCH="$(GOARCH_$(1))" \
	${GO} build $(GOEXTRAFLAGS) -v -o "$(BUILDDIR)/libssb-go-$(1).a" -buildmode c-archive && ${GO} version > "$(BUILDDIR)/.gobuildversion"; \
	ret=$$$$?; \
	rm -f "$(BUILDDIR)/libssb-go-$(1).h"; \
	exit $$$$ret
endef
$(foreach ARCH,$(ARCHS_PHONE),$(eval $(call libssb-go-a,$(ARCH))))

# build for sim with correct cflags
define libssb-go-sim-a
$(BUILDDIR)/libssb-go-sim-$(1).a: *.go
	CGO_CFLAGS="$(CFLAGS_SIM) -arch $(ARCH)" \
	CGO_LDFLAGS="$(CFLAGS_SIM) -arch $(ARCH)" \
	GOARCH="$(GOARCHSIM_$(1))" \
	${GO} build $(GOEXTRAFLAGS) -v -o "$(BUILDDIR)/libssb-go-sim-$(1).a" -buildmode c-archive && ${GO} version > "$(BUILDDIR)/.gobuildversion"
	ret=$$$$?; \
	rm -f "$(BUILDDIR)/libssb-go-sim-$(1).h"; \
	exit $$$$ret
endef
$(foreach ARCH,$(ARCHS_SIM),$(eval $(call libssb-go-sim-a,$(ARCH))))

# link all the archives for all the arches into the .a file
$(DESTDIR)/libssb-go.a: $(foreach ARCH,$(ARCHS_PHONE),$(BUILDDIR)/libssb-go-$(ARCH).a) $(foreach ARCH,$(ARCHS_SIM),$(BUILDDIR)/libssb-go-sim-$(ARCH).a)
	@mkdir -vp "$(DESTDIR)"
	$(LIPO) -create -output "$@" $^

clean:
	rm -rf "$(BUILDDIR)" "$(DESTDIR)/libssb-go.a"

install: build

.PHONY: clean build install
