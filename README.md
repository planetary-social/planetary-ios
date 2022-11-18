# Planetary iOS

[Website](https://planetary.social) | [Wiki](https://github.com/planetary-social/planetary-ios/wiki) | [Matrix](https://matrix.to/#/#planetary:matrix.org) | [Discord](https://discord.gg/aNgVthyHac)

![Unit Tests](https://github.com/planetary-social/planetary-ios/actions/workflows/main.yml/badge.svg) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/10d7934ffe4a46f380ff35951cc482e8)](https://www.codacy.com/gh/planetary-social/planetary-ios/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=planetary-social/planetary-ios&amp;utm_campaign=Badge_Grade) [![Crowdin](https://badges.crowdin.net/planetary/localized.svg)](https://crowdin.com/project/planetary)

Social media for humans, not algorithms.

Planetary passes data from friend to friend, creating a network that is personal, censorship resistant, and minimizes abuse and spam. Planetary gives you ownership over your relationships and content, and is compatible with any app using the Secure Scuttlebutt protocol.

In Planetary there are no advertisements or artificial intelligence algorithms trying to make you feel a certain way. Your content lives on your device and the devices of those around you, it isn't owned or controlled by a corporation. Experience social networking where you're the customer, not the product.

Unlike most social media, Planetary:
* Does not sell your data.
* Is naturally spam-resistant.
* Compatible with other apps including Manyverse, Patchwork, and more.
* Works off-grid and offline.
* Allows you to take your friends with you if you decide to move to another client.
* Is open source!

No one company should own the Internet’s public spaces, which is why we’re building on —and contributing back to— the open source [Secure Scuttlebutt](https://scuttlebutt.nz/) ecosystem. Their core technologies let us recreate a social network experience, but in a decentralized way that no one organization can dominate.

Check our website [planetary.social](https://planetary.social/) for more info! You can also find us on [Matrix](https://matrix.to/#/#planetary:matrix.org) and [Discord](https://discord.gg/aNgVthyHac).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

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
* Room Support (tunneling connections)
* Room Aliases

## Functionality Implemented in Planetary with only debug or api interface:
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
* Private Messaging up to 8 people
* Private groups
* Editing content
* Tombstoning content
* Partial feed replication
* Routing traffic over tor / anonymizing networks
* TrustNet transitive abuse moderation algorithm
* Suggest new people to follow
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

## License

[MPL-2.0](LICENSE)
