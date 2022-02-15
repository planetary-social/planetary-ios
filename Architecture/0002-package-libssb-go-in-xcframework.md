# 2. Package libssb-go.a in XCFramework

Date: 2022-01-06

## Status

Accepted

## Context

Apple has recently released Apple silicon in the form of M1 processors. This has implications for static libraries that include multiple slices for different architectures, like libssb-go.a. Libraries now need to include slices for architecture _and platform_ because you may have an arm64 binary compiled for macOS and an arm64 binary compiled for iOS. The fat binary format does not have room for platform information.

Apple's answer to this problem is a replacement for fat binaries: the XCFramework.

## Decision

Planetary will embed GoSSB.xcframework, instead of a single fat binary named libssb-go.a.

## Consequences

This will allow us to produce one version of our Go core that is valid for all platforms and architectures.

This presents another layer of complexity in compiling the Go core. In addition to knowing how to cross-compile Go for iOS, one also has to learn about the XCFramework format.
