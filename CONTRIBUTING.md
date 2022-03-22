# Contributing

Planetary is an open-source project, as such, we openly welcome contributions of any sort: code improvement, bug fixes, translations, new features, bug reports...

We encourage you to read this guide first or contact any of us.

## Architecture

**A good place to start: all of our important architectural decisions are being annotated inside the [Architecture folder](Architecture/) using [Architecture Decision Records](http://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions).**

Planetary is organized around [major components](https://developer.apple.com/documentation/swift_packages/organizing_your_code_with_local_packages). A quick look to the dependency graph:

```mermaid
graph TD
  Planetary((Planetary))
  Planetary-->Logger
  Planetary-->Secrets
  Planetary-->Analytics
  Planetary-->CrashReporting
  Secrets-->Logger
  Analytics-->Logger
  Analytics-->Secrets
  CrashReporting-->Logger
  CrashReporting-->Secrets
```

You can contribute by working on each of these packages, or in the Planetary app itself.

### Creating a Swift Package

In order to create a new package, follow these steps:

1. In Xcode, select File > New > Package...
2. Give it a name and be sure to select the Planetary workspace under `Add to` and `Group`
3. Add the package in `Framework, Libraries, and Embedded Content` under the `Planetary` target (in the `General` tab) and under `Link Binary with Libraries` under the `UnitTests` target (in the `Build phases` tab)
4. Be sure to make tests _execute in parallel_ and _in random order_ by turning on both options in Edit scheme > Test > Info
5. Be sure to enable _code coverage_ when running tests by turning on that option in Edit scheme > Test > Options
6. Add a new job in `.github/workflows/main.yml` just like the other packages

You are ready to go. Please, use other local swift packages like `Analytics` or `Logger` as a model to develop the new package and **write tests**, we are aiming to a code coverage of more than 90% in our packages.

### The Secrets.plist configuration file

In order to configure third-party libraries, we need to add API keys. They are listed in the [Secrets.debug.plist](Resources/Secrets.debug.plist) file with empty values, the app still works without them. When making a Release build, you will need a similar file named Secrets.release.plist added in the same folder.

Be sure to execute this in your local environment:

```git update-index --skip-worktree Resources/Secrets.debug.plist```

This prevent you from commiting real values in the repository.

## Bug Reports

Feel free to open an [issue on Github](https://github.com/planetary-social/planetary-ios/issues), be sure to include a good description of the bug you found.

## Translations

If you want to contribute by translating the app to another language, you can head in to our [project in Crowdin](https://crowdin.com/project/planetary) and start translating there. It will automatically generate a Pull Request that we will happily take care of merging.

## Pull Requests

For now `master` is the main branch and code improvements are made in topic branches that get merged into it.

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
