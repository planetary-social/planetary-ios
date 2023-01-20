---
name: Release
about: A checklist for deploying the Planetary iOS app to the App Store
title: Release X.X.X
labels: ''
assignees: ''

---

#  Build & Upload
- [ ] Checkout the latest commit of the `main` branch.
- [ ] Create a release branch including the version number like `release/1.0.16`.
- [ ] Update the preloaded feed using the instructions at https://github.com/planetary-social/feed_seralizer/blob/main/README.md
- [ ] Increment the version number if necessary, following [Semantic Versioning](https://semver.org/) guidelines. You can do this by running `fastlane bump_{major, minor, or patch}`. Fastlane will automatically bump the build number later on.
- [ ] Update [CHANGELOG.md](https://github.com/planetary-social/planetary-ios/blob/main/CHANGELOG.md) in the Github repository.
- [ ] Run `fastlane beta` to build and upload the app to TestFlight.
- [ ] Commit changes and push.

# Deploy to Planetary Employees
- [ ] Wait for the build to finish processing in the [TestFlight dashboard](https://appstoreconnect.apple.com/apps/1481617318/testflight/ios).
- [ ] Click on the build in the TestFlight Dashboard and past the CHANGELOG into the Test Details box.

# Deploy to Beta Testers
- [ ] Deploy the app to Planetary employees (see above)
- [ ] Ask Daniel to translate CHANGELOG into release notes.
- [ ] Enter release notes into the Test Details box.
- [ ] Click the + button in the Groups section and add the "Beta Public" group to distribute the build to our public beta testers.

# Submit for review
- [ ] Ask Sebastian to translate release notes into Spanish.
- [ ] Ask Filip to translate release notes into Polish.
- [ ] Open [App Store Connect](https://appstoreconnect.apple.com/apps/1481617318/appstore/ios/version/inflight) and click the blue plus button in the top left.
- [ ] Enter the version number, like "1.3.4" and click ok.
- [ ] Put the release notes in the What's New In This Version section for each language. You can change the language at the top.
- [ ] Select the correct build in the Build section.
- [ ] Select "Manually release this version" in the Version Release Section unless you have already completed testing and want the build to go out automatically. 
- [ ] Click "Save" in the top right.
- [ ] Click "Add for Review".
- [ ] Click "Submit for Review" on the next page.
- [ ] Perform final QA testing.

# After QA & App Store Review Approval
- [ ] Do a final check of [TestFlight feedback](https://appstoreconnect.apple.com/apps/1481617318/testflight/screenshots?appPlatform=IOS&preReleaseVersionId=2bc4c851-1818-4466-b04a-b9b4b9a282d5&sort=-timestamp) and [Github issues](https://github.com/planetary-social/planetary-ios/issues) for any blocking bugs.
- [ ] Create a new page in the [Release Notes section in Zendesk](https://planetarysupport.zendesk.com/hc/en-us/categories/360002335853-Release-Notes).
- [ ] Tag the deployed commit with the semantic version number i.e. "1.0.7".
- [ ] Create a [Github Release](https://github.com/planetary-social/planetary-ios/releases/new), copying in the tag name and a link to the CHANGELOG.
- [ ] Click "Release this Version" in [App Store Connect](https://appstoreconnect.apple.com/apps/1481617318/appstore/ios/version/inflight)
- [ ] Merge the release branch into `main` and delete it.
- [ ] Post release notes to Planetary account at https://planetary.rocks. (Connect to replicate with `sbot gossip.connect "net:planetary.rocks:8008~shs:l1sGqWeCZRA99gN+t9sI6+UOzGcHq3KhLQUYEwb4DCo="`)
- [ ] Post release notes on [Radaar](https://radaar.io)
- [ ] Post release notes on [Discord](https://discord.com/channels/776485686181363729/776485686181363732)
- [ ] Update this wiki page with any procedural changes.
