# Planetary

Social media for humans, not algorithms.

Planetary passes data from friend to friend, creating a network that is personal, censorship resistant, and minimizes abuse and spam. Planetary gives you ownership over your relationships and content, and is compatible with any app using the Secure Scuttlebutt protocol.

In Planetary there are no advertisements or artificial intelligence algorithms trying to make you feel a certain way. Your content lives on your device and the devices of those around you, it isn't owned or controlled by a corporation. Experience social networking where you're the customer, not the product.

Unlike most social media, Planetary:
* Does not sell your data
* Is naturally spam-resistant
* Compatible with other apps including Manyverse, Patchwork, and more
* Works off-grid and offline.
* Allows you to take your friends with you if you decide to move to another client.
* Is open source!

No one company should own the Internet’s public spaces, which is why we’re building on —and contributing back to— the open source [Secure Scuttlebutt](https://scuttlebutt.nz/) ecosystem. Their core technologies let us recreate a social network experience, but in a decentralized way that no one organization can dominate.

Check our website [planetary.social](https://planetary.social/) for more info!

## Current Planetary Functionality:
* Create a user
* Follow users
* Unfollow users
* Block users
* Reply to posts
* Mention other users
* Publish your profile with image, name, and description in rich text markdown.
* Join community servers (pubs) to connect to communities of users for default list
* Join community servers (pubs) using an invite link
* Create new community servers that users can use
* Defining initial network and pre-loaded content. 
* Publish content with rich text markdown (up to 8k)
* Publish content with images attached
* Discover new users who are in your extended network
* View feeds of content from people you’re following
* Background sync to trigger the app finding new content 
* Publish content with hashtags and discover content through hashtags
* Share content with people off network through a link to planetary.link
* Sync content between devices on the same local network
* View and post content while offline without any internet connection
* Strong cryptographic verification of who published what.
* Direct mesh networking between devices in physical proximity
* Nothing can be deleted
* Users can report encrypted and unencrypted content to Planetary for TOS violations
* Planetary can ban users from company run pubs
* Planetary can block users from using their identity in the app
* Planetary can prevent users from seeing banned messages or accounts
* Planetary can define who is in the initial directory and content upon installing the app
* Users can migrate their identity off of Planetary to access blacklisted content in other ssb apps

## Functionality Implemented in Planetary with only debug or api interface:
* Private Messaging up to 8 people
* Running multiple identities on a single instance of the app
* Running multiple distinct scuttlebutt networks.
* Backup and restore your keys to move identities (accounts) between apps
* User can manage local storage
* User should be informed about the data storage model for scuttlebutt
* User given an option to not connect to automatic pubs
* User can onboard from an invite to a specific user or community
* User can see what peers they’re connected to
* User can see most recent update time from each person network


## Functionality in Libraries but not in the app
* Private groups
* Editing content
* Tombstoning content
* Partial feed replication
* Routing traffic over tor / anonymizing networks
* TrustNet transitive abuse moderation algorithm
* Suggest new people to follow
* Room Support (tunneling connections)
* Direct serverless DHT Invite generation and redemption. 
* Log in to web services using scuttlebutt identity through QR code.
* Metafeeds (single identity key writer for multiple feeds for a single user)

## Functionality in a prototyping and spec stage
* Partial feed replication
* Multiple device for a single user (fusion identities) 
* Feed fork detection and recovery
* Serverless Messaging Layer Security (MLS) for group messaging. 
* Known Bugs
* A current list of known bugs in Planetary’s iOS app is in github issues. 
* Database on device occasionally gets corrupted
* New installs fail to initialize correctly rarely
* Connection information is only displayed on debug screens
* Sometimes users need to pull to refresh to see new content


![](https://github.com/planetary-social/planetary-ios/workflows/CI/badge.svg)

## Developer installation

### Setup

You should be able to Build and Run in Xcode without installing any external tools other than Xcode.

If you need to change a dependency, install the `cocoapods` dependency manager first:

1. Install `rbenv` using [Homebrew](https://brew.sh/) and add it to your shell: 

```
$ brew install rbenv && rbenv init
```

2. Install ruby v2.7.5

```
$ rbenv install 2.7.5
```

3. Install gem

```
$ gem install cocoapods
```

4. Install dependencies

```
$ pod install
```

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
