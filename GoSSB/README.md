# GoSSB

GoSSB is designed to bundle libssb-go aka https://github.com/cryptoscope/ssb as an [XCFramework](https://help.apple.com/xcode/mac/current/#/dev544efab96) so that it can be imported into an iOS app. XCFrameworks are Apple's preferred alternative to fat binaries in the age of Apple Silicon. Fat binaries cannot contain two slices targeting the same architecture but different platforms, which is now required to build a library that supports the iOS simulator on an M1 Mac (macos arm64) and a real iphone (ios arm64).

## Adding Architectures
GoSSB compiles the Go code with `make` for a predetermined set of architectures. If more architectures need to be added in the future they will need to be manually addded to the Makefile and the "Build GoSSB.xcframework" build phase.

## Go Development

See `../Scripts/go_install.sh` for which compiler version is used by XCode.

We are using _vendoring_ to keep a copy of the dependencies in this repo. Therefore each module update (`go get github.com/some/import/...@version`) needs to be followed by running `go mod vendor` and committing the resulting changes.

To rebuild GoSSB.xcframework you can make changes to the files in the `Sources` directory. Then open `GoSSB/GoSSB.xcodeproj` and select Product > Build. The resulting XCFramework can be found at `Products/GoSSB.xcframework`.

ps: If you are already using [Homebrew](https://brew.sh/) you can also use `brew install go` instead of the installer from golang.org
