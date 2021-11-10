# Planetary

Planetary IOS is an app based on [Secure Scuttlebutt](https://scuttlebutt.nz/) that doesn't keep your data in the cloud and allows you and your friends to come together and connect even when the internet goes out.  
Check our website [planetary.social](https://planetary.social/) for more info!

![](https://github.com/planetary-social/planetary-ios/workflows/CI/badge.svg)

## Developer installation

_Only tested on Intel Macs_

### Setup

Requirements: [Homebrew](https://brew.sh/), and Xcode.

The repo does have some Carthage and Cocoapod dependencies, however all except one have been versioned and checked into the repo.

While this project uses [Go](https://golang.org) in parts, the build and unit test target have automated install scripts for the specific versions. See _Go Development_ for more.

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
$ gem install cocoapods cocoapods-keys cocoapods-bugsnag
```

4. Install cocoapods. When running `pod install` (or `pod install --no-repo-update`) you will be prompted to enter some secrets. Enter `nil` for all of them or request current values at: https://planetarysupport.zendesk.com/hc/en-us/requests/new.

```
$ pod install
```

5. If you entered `nil` for the Bugsnag API Key in the `pod install` step you will need to disable the Upload Bugsnag dSYM Build Phase. To do this, open the project settings (In the File Inspector, select 'Planetary' at the top), Selet the 'Planetary' target on the left, select "Build Phases" at the top, then comment out or remove the Upload Bugsnag dSYM script.


### Running

The app can run completely in the iOS simulator. If you want to run it on a device, your Apple ID must be part of the Verse Apple Developer team. Contact contact@verse.app if you need access.

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

Installation in the xcode targers is automated. See `FBTT/Scripts/go_install.sh` for which compiler version is used by XCode.

We are using _vendoring_ to keep a copy of the dependencies in this repo. Therefore each module update (`go get github.com/some/import/...@version`) needs to be followed by running `go mod vendor` and commiting the resulting changes.

If you have a seperate Go installation, run the following script to test that everything works as intended run

```bash
export GOROOT=$(go env GOROOT)
test -d $GOROOT || exit 1 # the makefile needs GOROOT to be set
cd FBTT/go-ssb-bindings
make
ls out/libssb-go.a`
```

ps: If you are already using [Homebrew](https://brew.sh/) you can also use `brew install go` instead of the installer from golang.org

## License

[MPL-2.0](LICENSE)

