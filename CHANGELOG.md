# Changelog
All notable changes to this project will be documented in this file.

We define "Noteworthy changes" as 1) user-facing features or bugfixes 2) significant technical or architectural changes that contributors will notice. If your Pull Request does not contain any changes of this nature i.e. minor string/translation changes, patch releases of dependencies, refactoring, etc. then add the `Skip-Changelog` label. 

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Added queer.family pub #726
- Max-Rai contributed a fix to the onboarding layout for smaller iOS screen sizes #703 (thanks @Max-Rai!)

## [1.2.3] 2022-07-11

- Added new tab bar icons. #691
- Show welcome tutorial messages to users who haven't opened the app in over a month. #695 
- Replace timestamp / posted x days ago with posters identity in home feed. #660 
- Fix some pub names and images not updating #540
- Tweaked design of the follow message cells. #699
- Don't show loading indicator when publishing a like/vote #672 

## [1.2.2] 2022-07-04

- Add a basic search bar to the Discover tab that allows you to search for posts. #679
- Fix the layout of the Discover tab on macOS. #683
- Changed name and description of "Reset Planetary" button to "Delete My Identity" #674
- Added regular SQLite database optimization. #684
- Added new tutorial messages in the Home feed for new users. #687
- Change Recently Active Posts and Contacts home feed algorithm so that votes do not bring posts to the top of the feed anymore.
- Fixed incorrect Golang version during builds #678
- Fixed go-ssb logs not being submitted after crash #677

## [1.2.1] 2022-06-27

- Added a badge to the Home Feed when there are new posts available. #663
- Allow lookup of user IDs outside your network on Your Network tab. #642
- Allow lookup of individual messages by ID on Your Network tab. #642
- Fixed a bug where posts from blocked users could show up in the Discover feed. #639
- Improve performance of the recently downloaded post count in the side menu. #637
- Fixed a bug where blocks were showing up as follows in the Home Feed. #619
- Fixed a bug in the background color on follow messages in dark mode. #620
- Made follow message loading state more dynamic so that it shows individual pieces of info as soon as they are ready. #636
- Fixed the ban list API so that Planetary can ban users violating our ToS. #631
- Improved blob propagation when posting images. #626
- The threaded conversation view now shows likes posted from other SSB clients. #610
- Hashtags on the Hashtags tab are now sorted by popularity. #614
- Changed text on the first two onboarding screens to better explain Planetary. #653
- Allow users to skip setting their name during onboarding. #659

## [1.2.0] 2022-06-01

- Updated to the latest version of our SSB library which requires us to delete and resync all data from the network. #510
- Added a section in the Settings menu to let you choose from several algorithms for the Home Feed. #565
- Changed default home feed algorithm to show follow messages. #532
- Added a Home Feed algorithm that moves posts back to the top of your feed when they receive a reply. #565
- Added a search bar to the Hashtags screen #570
- Improved loading of images. #535
- Display year in timestamps on old posts. @jyu1129 #560 
- Removed connection firewall in go-ssb. Planetary will now replicate with any other SSB client on your local network. #435
- Fixed an issue where Planetary would incorrectly prevent the user from posting with a message about it restoring. #548
- Added option in onboarding to follow Planetary identity. #513
- (re-)Added option during onboarding to opt out of analytics. #513
- Changed database to show all messages, even those older than 6 months. #513
- Changed debug builds to use the Planetary Test Network rather than the SSB main network caps. #470
- Remove in-app image cropping since it was buggy #568
- Update style of photo gallery page indicator #569
- Fixed usernames getting clipped on the Discover tab #589
- Reduced app launch time #598
- Improved replication performance. #553 #533 #604
- Updated Spanish translation
- Thread view now sorts replies by claimed timestamp instead of received timestamp #609

## [1.1.2] 2022-04-29
- Fixed invitations for Gardening and Poetry pubs #503
- Fixed onboarding analytics events #501
- Added a button in the debug menu to reset forked feed protection #498
- Fixed forked feed protection false positive after importing key #498

## [1.1.1] = 2022-04-18
- Added Russian and Ukrainian language pubs to the community pub list #474
- Fixed secret key JSON overflowing its text box in the debug settings #493 @cappster
- Fixed some error messages showing placeholder text instead of localized text #476
- Fixed a case where no error message was shown if adding a photo failed #482
- Fixed a bug where the users feed could be forked after importing a key using the debug menu. #495
- Fixed a bug where Planetary would publish duplicate pub messages. #495 
- Fixed the embedded invitation to Planetary System Pub 3 #477 

## [1.1.0] = 2022-04-04
- Added several new community pubs #450
- Rename the "User Directory" tab to "Your Network" #450
- Redesigned "like" messages to be smaller #448
- Fixed forked feed protection #437
- Fixed pubs showing up twice on the User Directory/Your Network tab #450
- Fixed a crash that could occur when trying to view a photo #464
- Changed replication algorithm to connect to pubs more often #465

## [1.0.23] = 2022-03-21
- Fixed translations being in the wrong language (again, the last build was not deployed correctly).

## [1.0.22] = 2022-03-17

### Fixed
- Fixed translations being in the wrong language. #427

## [1.0.21] = 2022-03-14

### Added
- Added a section showing connected peers and number of synced messages in the side menu. #405
- Added a placeholder image for unsupported blob types. #412

### Fixed
- Fixed blob loading (in most cases). #412
- Fixed analytic event formats. #397

## [1.0.20] = 2022-02-22
### Fixed
- Allow Planetary to sync data for longer periods of time (up to 30 seconds) when the app is in the backgound. #381
- Fix new posts not showing at the top of user Profile pages. #377
- Fixed a crash when tapping the share button on the Profile page. #378
- Fixed popover menus on iPads in landscape orientation. Popover menus were pointing to the wrong places in portrait, and crashing the app in landscape. #350 (@kode54)

### Added
- Added an option to export your database in the Debug menu. #338
- Added support for the new planetary.link URL format. #352

## [1.0.19] = 2022-02-03
### Fixed
- Fixed a bug that prevented pub invitations from being redeemed. #333 (@kode54)

## [1.0.18] = 2022-02-01
### Fixed
- Fixed a case where the app could become unresponsive while writing to the database. #310
- Fixed a case where the app could become unresponsive while trying to redeem an invitation to a pub. #302
- Fixed an issue where the SQLite database could get significantly behind the go-ssb log, resulting in new data not being shown in the UI. #304
- Fixed an issue where placeholder cells would be shown after posts had finished loading. #316  
- Fixed a bug where the mentions autocomplete drawer would not go away. #320

## [1.0.17] = 2022-01-24
### Fixed
- Fixed an issue where the Follow button could be unresponsive #252

### Changed
- Changed sorting of the posts in the For You tab to prioritize new content. Instead of sorting by the time the post was received we sort by the time the post was posted. #293
- Updated translations

## [1.0.16] = 2022-01-11
### Changed
- Updated preloaded feed
- Updated translations #242
- Updated Zendesk SDK

## [0.9.30] = 2020-08-21
## Fixed
- Changes in the way the app connects to peers in the network fixes major bug in the app which makes the performance of the feel slow.

## [0.9.29] - 2020-07-09
## Added
- Followers are sorted by name.
- You can now search among your followers by name or identity.

## Fixed
- Tooling and statistics to figure out why some users aren't seeing updates and syncs.

## [0.9.28] - 2020-06-29
## Added:
- Explore content in the all new discover screen.
- Block users.
- Give hearts instead of liking a post.
- Tap the network status doodle to trigger a sync.

## Fixed:
- Issues some users where having syncing the latest posts.

## [0.9.27] - 2020-06-11
## Added:
- We preload some feeds when onboarding so you don't have to wait to see something.
- Blob loading spinner.
- Load blobs from cloud as fallback.

## [0.9.25] - 2020-05-28
## Added:
- New posts - Pull to refresh notification
- Directory includes all the people in your follow network, not just planetary users
- Note on posts reminding users they can use markdown

## Fixed: 
- Upper left profile avatar now shows your profile avatar

## [0.9.24] - 2020-05-25
## Added:
- changing explore so it only shows you people you're not following
- enable universal links for planetary.link

## Fixed:
- no more rebuilding db, now it just overwrites duplicate data
- skip nulled messages in private log
- scroll top when tapping on the explore icon
- only display blobs which are images
- fall back to blobs hosted by planetary if muxrpc fails to get them over ssb

## [0.9.23] - 2020-05-23
## Added:
- Updated tab bar icon assets
- Adding localization for Castillian Spanish
- Add Uruguayan and Argentinian Rioplatenses localizations
- Add basic support for UI Tests
- Add support for displaying likes
- Displaying Pub Names

### Fixed:
- Fixed bug with background sync on new notifications
- Optimize onboarding sync and refresh
- Clean up analytics for optional mixpanel metrics
- Change DBTests so that take into account likes
- update to go-ssb rc4
- rework bot.login & logout > login flow
- add timestamp to gobot logging
- fix timestamp setup on log files
- make timestamp swift-like but it's still UTC
- support re-syncing of existing key-pair
- re-do failed login dialog
- re-work restart on bot.login failure
- update english error text
- fixing it so the reply count includes likes
- fix closing of contacts index
- stop open connections during fsck
- reduce number of sync connections
- gobot: start in the background
- gobot.login: refactor defer->completion flow

## [0.9.22] - 2020-05-10
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
