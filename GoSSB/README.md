# GoSSB

GoSSB is designed to bundle libssb-go aka https://github.com/cryptoscope/ssb as an [XCFramework](https://help.apple.com/xcode/mac/current/#/dev544efab96) so that it can be imported into an iOS app. XCFrameworks are Apple's preferred alternative to fat binaries in the age of Apple Silicon. Fat binaries cannot contain two slices targeting the same architecture but different platforms, which is now required to build a library that supports the iOS simulator on an M1 Mac (macos arm64) and a real iphone (ios arm64).

## Adding Architectures
GoSSB compiles the Go code with `make` for a predetermined set of architectures. If more architectures need to be added in the future they will need to be manually addded to the Makefile and the "Build GoSSB.xcframework" build phase.
