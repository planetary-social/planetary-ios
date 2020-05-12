# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.21] - 2020-05-10
### Added:
- New system for loading content so the UI updates faster and you can scroll back through history as far as you want.
- Changed the explore tab to show replies and new posts to help with discovering new content.

### Fixed:
- Fix bug where if you had more than 50 follows you wouldn't see new follows in your notifications tab.
- Changed Mixpanel actions to log user navigation through the app instead of just bot behavior. 
- Attaching GoBot logs to Share logs in Debug, to Bugsnag crash reports and to Zendesk tickets.
- Fix bug in background sync on notification of new content. 

## [0.9.21] - 2020-04-30
### Added
- All new Explore tab that shows posts from your greater network.
- New sync/refresh strategy that should be better at having your feed up to date.

## [0.9.21] - 2020-04-30
### Added
- All new Explore tab that shows posts from your greater network.
- New sync/refresh strategy that should be better at having your feed up to date.

## [0.9.20] - 2020-04-16
### Added
- Public profile links now work with the public identifier.
### Fixed
- Loading the main feed and notifications is faster than ever.
- Opening the left menu is instant now.

## [0.9.19] - 2020-04-09
### Added
- Automatically detect links in posts.
### Fixed
- Images not displayed in order in the gallery.
- Bug that prevented login for some users.
- But that prevented displaying posts with code blocks in iOS 12.

## [0.9.18] - 2020-04-08
### Added
- Complete support of CommonMark (an unambiguous spec of Markdown)
### Fixed
- Minor bugfixes regarding the use of Scuttlebutt.

## [0.9.17] - 2020-04-06
### Added
- Sync when pulling down to refresh on the feed.
### Fixed
- Links not displayed properly in posts.
- Images looked like broken links in posts.
- Background sync not working.

## [0.9.16] - 2020-04-02
### Added
- New Planetary typeface.
- Share your profile link to the world.
- Loading animation for Notifications and Channels screens.
### Fixed
- Show alert dialogs when errors occur.
- Report handled errors.

## [0.9.15] - 2020-03-26
### Fixed
- Post button not appearing when undocking the keyboard.
- Crash when downloading logs in iPad.
- Empty log when downloading logs.
- Crash when database repair fails.
- Bad wording for number of replies in a post.

## [0.9.14] - 2020-03-25
### Added
- Show spinning wheel when processing new messages.
### Fixed
- Issue with reply count different than replies shown.
- Avatars when mentioning someone were displayed incorrectly sometimes.
- Avatar disappearing when switching tabs.
- Performance issues with Notification screen.

## [0.9.13] - 2020-03-20
### Fixed
- Login is now more efficient.
- Posted hashtags are now compatible with other networks.
- Fix hashtags with - sign in the middle.
- Channels screen is sorted by newest to oldest.

## [0.9.12] - 2020-03-17
### Added
- Now you can open your profile tapping on your profile photo.  

### Fixed
- Syncing is now more efficient.
- Posted images are now compatible with other networks, like Patchwork.
- Fix bug that prevented using the app after opening an image in full screen.
- If you happen to touch a link while you are scrolling, the app doesn't open the link anymore.

## [0.9.11] - 2020-03-10
### Added
- Redeem invitations: Do you want to follow a pub? Now you can now redeem invitations in Settings > Manage Pubs!
- Switch to main net: The app now works in the main net, so expect to be prompted to logout and onboard again, otherwise the app won't work fine. Go to Settings > Advanced Settings and tap on Reset application and identity, or alternatively, go to Settings > Advanced Settings > Dangerous and powerful debug menu and tap on Logout and onboard.

### Fixed
- Performance improvements and minor bug fixes.
