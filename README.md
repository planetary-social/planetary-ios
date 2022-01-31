# Planetary

Planetary iOS is an app based on [Secure Scuttlebutt](https://scuttlebutt.nz/) that doesn't keep your data in the cloud and allows you and your friends to come together and connect even when the internet goes out.  
Check our website [planetary.social](https://planetary.social/) for more info!

![](https://github.com/planetary-social/planetary-ios/workflows/CI/badge.svg)

## Developer installation

### Setup

Requirements: [Homebrew](https://brew.sh/), and Xcode.

1. Install `rbenv` and add it to your shell: 

```
$ brew install rbenv && rbenv init
```

2. Install ruby v2.6.6

```
$ rbenv install 2.6.6
```

3. Install gems

```
$ gem install cocoapods cocoapods-keys
```

4. Install cocoapods. When running `pod install` (or `pod install --no-repo-update`) you will be prompted to enter some secrets. Enter `nil` for all of them. The app is still functional without these keys, it just won't submit support tickets, analytics, or crash reports to us.

```
$ pod install
```

5. You should now be able to Build and Run in Xcode.

### Running

The app is fully functional in the iOS simulator. If you want to run it on a device you will need to change the Bundle Identifier and Code Signing settings to use your personal team.

## Contributing

For now `master` is the main branch and code improvements are made in topic branches that get merged into it. Eventually there will be specific release branches, but for now `master` is the release branch.

1. Create a branch named `initials-topic` or ticket tag like `esw-190`
2. dd commits at whatever pace/detail necessary (these are mostly for your benefit)
3. Push your named branch
4. Add a short description of what the PR accomplishes
5. If possible add screenshots (use shift-command-4-space-click to capture the iOS simulator window)

Due to the small team size, code reviews are mostly to inform other members what's going on. Use GitHub's inline comment feature to leave notes for others to read and reply.

### Merging a Pull Request

1. Select "Squash and merge" from the drop-down Merge button.
2. Delete the branch (as the UI recommends) to keep the repo clean.

## Go Development

Planetary’s underlying SSB protocol implementation is written in Go (see [cryptoscope/ssb](https://github.com/cryptoscope/ssb)). The GoSSB folder contains an Xcode project that packages [cryptoscope/ssb](https://github.com/cryptoscope/ssb) as an XCFramework that works across Apple’s various platforms and architectures. GoSSB.xcframework is included in this repository so that contributors don’t need to install a full Go stack to work on the iOS app. More information about the GoSSB.xcframework can be found in its [README](GoSSB/README.md)


## License

[MPL-2.0](LICENSE)

