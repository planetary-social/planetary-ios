**SET UP**

The repo does have some Carthage and Cocoapod dependencies, however all have been versioned and checked into the repo.  You should be able to clone the repo, open `FBTT.xcodeworkspace`, select the `FBTT` target, then click the ▶ button.  You must open the workspace file, not the project file, to build and run.

While this project uses [Go](https://golang.org) in parts, the build and unit test targets of the XCode project have automated install scripts for the specific versions. See _Go Development_ for more.

**CONFIGURE**

Before running the app, you need to complete the configuration files stored inside `Config` folder (just update Shared.debug.xcconfig and Shared.release.xcconfig). Request current values at: https://planetarysupport.zendesk.com/hc/en-us/requests/new.

**LAUNCH & RUN**

To install and run on a device, your Apple ID must be part of the Verse Apple Developer team.  Contact contact@verse.app if you need access.

The app can run completely in the iOS simulator, however you will need a valid mobile phone number to complete the SMS verification step during onboarding.

If you are unable to complete onboarding (it hangs during "Creating your Verse identity), then it is possible that the simulator cannot communicate with Verse servers or the internal HTTP server (soon to be deprecated).  Ensure your host computer does not have a funky `etc/hosts` configuration or other network issue.

**BRANCHES**

For now `master` is the main branch and code improvements are made in topic branches that get merged into it.  Eventually there will be specific release branches, but for now `master` is the release branch.

1.  Create a branch named `initials-topic` or ticket tag like `esw-190`
2.  Add commits at whatever pace/detail necessary (these are mostly for your benefit)
3.  

**PULL REQUESTS**

1.  Push your named branch
2.  Add a short description of what the PR accomplishes
3.  Add test steps (as necessary)
4.  If possible add screenshots (use shift-command-4-space-click to capture the iOS simulator window)

**CODE REVIEWS**

Due to the small team size, code reviews are mostly to inform other members what's going on.  Use GitHub's inline comment feature to leave notes for others to read and reply.

**MERGES**

1.  Select "Squash and merge" from the drop-down Merge button.
2.  Delete the branch (as the UI recommends) to keep the repo clean.

**GO DEVELOPMENT**

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
