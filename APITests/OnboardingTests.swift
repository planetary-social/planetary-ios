//
//  FBTTAPITests.swift
//  FBTTAPITests
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import XCTest

private let publishManyCount = 125

class OnboardingTests: XCTestCase {
    
    // state can be carried between test steps by using a static var
    // you can specific a non-optional value to avoid guard statements
    // but that may crash if you don't assert not nil first
    static var context: Onboarding.Context!

    // remove previous runs first
    // helps starting with a clean slate from failed runs
    func test00_cleanup() {
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        if appSupportDirs.count < 1 {
            XCTFail("no support dir")
            return
        }
        let repo = appSupportDirs[0]
            .appending("/FBTT")
            .appending("/"+NetworkKey.integrationTests.hexEncodedString())
        do {
            print("dropping \(repo)")
            try FileManager.default.removeItem(atPath: repo)
        } catch {
            print("failed to drop testdata repo, most likely first run")
        }
    }

    func test01_start() {
        let expectation = self.expectation(description: "Start Onboarding")

        var name = "APITest \(Date().shortDateTimeString)"
        if let circleBuild = ProcessInfo.processInfo.environment["CIRCLE_BUILD_NUM"] {
            name += "(CircleCI:\(circleBuild))"
        }
        Onboarding.start(birthdate: Date.random(yearsFromNow: -21),
                         phone: "4155555785",
                         name: name) {
            context, error in
            XCTAssertNil(error, "\(error.debugDescription)")
            XCTAssertNotNil(context)
            XCTAssertNotNil(context?.identity)
            XCTAssertNotNil(context?.about)
            XCTAssertNil(context?.person) // TODO: test directory
            OnboardingTests.context = context
            print("created ID: \(context?.identity ?? "<none>")")
            XCTAssertEqual(context?.network.hexEncodedString(), NetworkKey.integrationTests.hexEncodedString())
            XCTAssertEqual(OnboardingTests.context.bot.statistics.repo.messageCount, 1)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test02_pub_doesnt_know_us_yet() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Pubs are online on TestAPI")

        TestAPI.shared.pubsAreOnline {
            yes, err in
            XCTAssertNil(err, "\(err.debugDescription)")
            XCTAssertTrue(yes)
            
            TestAPI.shared.onboarded(who: ctx.identity, messageCount: 1) {
                res, err in
                XCTAssertNotNil(err)
                if let res = res {
                    XCTFail("pre-test ID already onboarded!: \(res)")
                }

                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test10_about() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Get current about")

        ctx.bot.about {
            info, error in
            XCTAssertNil(error, "\(error.debugDescription)")
            guard let i = info else {
                XCTFail("nil info")
                expectation.fulfill()
                return
            }
            XCTAssertTrue((i.name?.starts(with: "APITest"))!)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test11_about_landed_in_db() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Refresh bot")

        ctx.bot.refresh(completion: {
            (err, _) in
            XCTAssertNil(err)
            XCTAssertEqual(OnboardingTests.context.bot.statistics.repo.messageCount, 1)
            expectation.fulfill()
        })

        self.wait(for: [expectation], timeout: 10)
    }

    // TODO: pull of VerseAPI.directory
    func test20_follow() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Follow identities")

        let identities = Identities.for(NetworkKey.integrationTests)
        Onboarding.follow(identities, context: ctx) {
            worked, contacts, err in
            XCTAssertEqual(err.count, 0)
            XCTAssertTrue(worked)
            XCTAssertEqual(contacts.count, 1)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test21_follow_landed_in_db() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Refresh bot")

        ctx.bot.refresh {
            err, _ in
            XCTAssertNil(err)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)

        XCTAssertEqual(OnboardingTests.context.bot.statistics.repo.messageCount, 2)
    }

    func test22_has_viewdb_follows() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Get current follows")

        ctx.bot.follows(identity: ctx.identity) {
            follows, error in
            XCTAssertNil(error, "\(error.debugDescription)")
            XCTAssertEqual(follows.count, 1)
            XCTAssertTrue(follows.contains(Identities.testNet.pubs["integrationpub1"]!))
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test30_can_publish_blob() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        guard var badImage = Data(base64Encoded: "/9j/4AAQSkZJRgABAQAASABIAAD/4QBwRXhpZgAATU0AKgAAAAgABAEGAAMAAAABAAIAAAESAAMAAAABAAEAAAEoAAMAAAABAAIAAIdpAAQAAAABAAAAPgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAD6ADAAQAAAABAAAADwAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgADwAPAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMACQkJCQkJDwkJDxUPDw8VHBUVFRUcIxwcHBwcIysjIyMjIyMrKysrKysrKzMzMzMzMzw8PDw8Q0NDQ0NDQ0NDQ//bAEMBCgsLERARHRAQHUYvJy9GRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRkZGRv/dAAQAAf/aAAwDAQACEQMRAD8Avpb3TorXE7K+BuEeAobHOMgnGemaj+1rZzeReTKQRlXbAP0OOPoa1MVn3mm217Ikso+ZM8+oPY1784ySvDc8lNdT/9k=") else {
            XCTFail("image corrupted")
            return
        }

        XCTAssertEqual(badImage.count, 869) // decoded correctly

        // randomize input to get random, unique blobs
        badImage.flipTwoBytes()
        // this might break JPG but let's see..

        // blatenty copy of primary() in PhotoConfirmOnboardingStep
        // TODO: we should somehow refactor what does the api stuff from the _is it an image_ stuff? https://app.asana.com/0/0/1134329918920787/f

        let expectation = self.expectation(description: "Add blob")

        ctx.bot.addBlob(data: badImage) {
            imgref, error in
            XCTAssertNil(error)

            let img = Image(link: imgref) // TODO: how to do I make an image from Data() ?
            guard var about = ctx.about?.mutatedCopy(image: img) else {
                XCTAssertNil(error)
                expectation.fulfill()
                return
            }
            if let buildHash = ProcessInfo.processInfo.environment["CIRCLE_SHA1"] {
                about = about.mutatedCopy(description: "(Commit SHA1:\(buildHash))")
            }

            ctx.bot.publish(content: about) {
                _, error in
                XCTAssertNil(error)
//                ctx.about?.image = img
                // TODO: can't update image on about or about on context
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }

    // make sure this is a fresh blob (calls blobs.has on the pub)
    // side-effect, will call blobs.want on the pub to fetch it for the 2nd try later
    func test39_not_on_pub_yet() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }
        guard let name = ctx.about?.name else {
            XCTFail("no name")
            return
        }

        // TODO: can't update image on about or about on context (see prev test)
//        guard let image = ctx.about?.image?.link else {
//            XCTFail("no image link")
//            return
//        }

        let expectation = self.expectation(description: "Set current onboarded")
        
        ctx.bot.about {
            newAbout, err in
            XCTAssertNil(err)

            guard let img = newAbout?.image else {
                XCTFail("still no image on about")
                expectation.fulfill()
                return
            }

            TestAPI.shared.onboarded(who: ctx.identity,
                             name: name,
                             image: img.link,
                             messageCount: 1
            ) {
                res, err in
                XCTAssertNotNil(err)
                if let res = res {
                    XCTFail("test39: ID already onboarded!: \(res)")
                }
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test40_invite_pubs() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }
        // TODO: https://app.asana.com/0/0/1134329918920786/f
        // this uses the TestAPI instead of Onboarding.invitePubsToFollow, which is currently hardcoded to PubAPI

        let expectation = self.expectation(description: "Invite pubs to follow")

        TestAPI.shared.invitePubsToFollow(ctx.identity) {
            success, error in
            XCTAssertNil(error)
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test41_connectToPubs() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Sync and refresh bot")

        ctx.bot.sync {
            err, _, _ in
            XCTAssertNil(err)
            ctx.bot.refresh {
                (err, _) in
                XCTAssertNil(err)

                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 30)
        sleep(5)
    }

    func test42_refresh() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Refresh bot")

        ctx.bot.refresh {
            (err, _) in
            XCTAssertNil(err)
            XCTAssertGreaterThan(ctx.bot.statistics.repo.messageCount, 3)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 30)
        sleep(5)
    }

    func test43_got_messages_from_pub() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Get feed")

        ctx.bot.feed(identity: Environment.Constellation.stars.first!.feed) {
            msgs, err in
            defer { expectation.fulfill() }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTAssertGreaterThan(ctx.bot.statistics.repo.feedCount, 1, "didnt even get feed")
                XCTFail("Expected init message from pub")
                return
            }
            guard let msg = msgs.last else { XCTFail("expected msg"); return }
            XCTAssertEqual(msg.contentType, .post)
            XCTAssertTrue(msg.value.content.post?.text.hasPrefix("Setup init:") ?? false)
        }

        self.wait(for: [expectation], timeout: 30)
    }

    func test50_ask_pub_about_new_id() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }
        guard let name = ctx.about?.name else {
            XCTFail("no name")
            return
        }

        // TODO: can't update image on about or about on context (see test30_can_publish_blob)
        //        guard let image = ctx.about?.image?.link else {
        //            XCTFail("no image link")
        //            return
        //        }

        let expectation = self.expectation(description: "Get onboarded")

        ctx.bot.about {
            newAbout, err in
            XCTAssertNil(err)

            guard let img = newAbout?.image else {
                XCTFail("still no image on about")
                expectation.fulfill()
                return
            }

            TestAPI.shared.onboarded(who: ctx.identity,
                             name: name,
                             image: img.link, // TODO: fix blob sync reliability https://app.asana.com/0/964832917280469/1141354135496673/f
                             messageCount: 3
            ) {
                res, err in
                XCTAssertNil(err)
                if let res = res {
                    print("ID onboarded!\(res)")
                }
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }

    // this just makes sure we can can follow a large chunk of people, like the directory selection might do
    func test51_follow_a_bunch() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }
        // these are fake keys (as the static pattern indicates)
        //  20 common names with Verse and Xs appended so they are 32bytes long
        let set1: [Identity] = [
            "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@SGFubmFoVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@SnVsaWFWZXJzZVhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TGFyYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TGF1cmFWZXJzZVhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TGVhVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TGVuYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TGlzYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TWljaGVsbGVWZXJzZVhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@U2FyYWhWZXJzZVhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@RmlublZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@SmFuVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@SmFubmlrVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@Sm9uYXNWZXJzZVhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TGVvblZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@THVjYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@THVrYXNWZXJzZVhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@TmlrbGFzVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@VGltVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            "@VG9tVmVyc2VYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
        ]

        let expectation = self.expectation(description: "Follow identities")

        Onboarding.follow(set1, context: ctx) {
            worked, contacts, errs in
            XCTAssertEqual(errs.count, 0)
            XCTAssertTrue(worked)
            XCTAssertEqual(contacts.count, 20)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test52_have_new_follows_locally() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Refresh and get follows")

        ctx.bot.refresh {
            (err, _) in
            XCTAssertNil(err)

            ctx.bot.follows(identity: ctx.identity) {
                (contacts, err) in
                XCTAssertNil(err)
                XCTAssertGreaterThanOrEqual(contacts.count, 20) // the two pubs are filtered
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test53_trigger_sync_of_new_follows() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Sync bot")

        ctx.bot.sync {
            err, _, _ in
            XCTAssertNil(err)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 30)
        sleep(10) // TODO: we need a better tool to wait until outgoing syncs finish
    }

    func test54_pub_has_new_messages() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Get onboarded")

        TestAPI.shared.onboarded(who: ctx.identity,
                                 messageCount: 23,
                                 follows: "set1"
        ) {
            _, err in
            XCTAssertNil(err)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 60)
    }

    func test60_PublishMany() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        var expectations = [XCTestExpectation]()
        for i in 1...publishManyCount {
            let expectation = self.expectation(description: "Publish \(i)")

            ctx.bot.publish(content: Post(text: "hello tests! (msg no \(i))")) {
                (_, publishErr) in
                XCTAssertNil(publishErr)

                expectation.fulfill()
            }

            expectations.append(expectation)
        }

        self.wait(for: expectations, timeout: 30)
    }

    func test61_trigger_sync_of_new_follows() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Sync and refresh bot")

        ctx.bot.sync {
            err, _, _ in
            XCTAssertNil(err)
            ctx.bot.refresh {
                err, _ in
                XCTAssertNil(err)
                XCTAssertGreaterThan(ctx.bot.statistics.repo.messageCount, publishManyCount + 3)
                expectation.fulfill()
            }
        }
        self.wait(for: [expectation], timeout: 60)
        sleep(5)
    }

    func test62_pub_has_many_messages() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }
        // TODO: see test50

        let expectation = self.expectation(description: "Set current onboarded")

        ctx.bot.about {
            newAbout, err in
            XCTAssertNil(err)

            // make sure we got the image on the 2nd try
            guard let img = newAbout?.image else {
                XCTFail("still no image on about")
                expectation.fulfill()
                return
            }

            TestAPI.shared.onboarded(who: ctx.identity,
                                     image: img.link,
                                      messageCount: 23 + publishManyCount
            ) {
                res, err in
                XCTAssertNil(err)
                if let res = res {
                    print("ID onboarded!\(res)")
                }
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 60)
    }

    // last one switches the lights off
    func test91_unfollow_new_key() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Unfollow")

        TestAPI.shared.letTestPubUnfollow(ctx.identity) {
            worked, err in
            XCTAssertTrue(worked)
            XCTAssertNil(err)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }

    func test92_shutdown() {
        guard let ctx = OnboardingTests.context else {
            XCTFail("no context")
            return
        }

        let expectation = self.expectation(description: "Logout")

        ctx.bot.logout {
            err in
            XCTAssertNil(err)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 10)
    }
}

fileprivate extension Data {
    mutating func flipTwoBytes() {
        let size = UInt32(self.count)

        // pick any byte in the data array
        let seedIdx = Int(arc4random_uniform(size))
        let seed = self[seedIdx]

        // pick two other bytes to flip
        var a = Int(arc4random_uniform(size))
        var b = Int(arc4random_uniform(size))

        // check that A and B are in bounds
        if a == seedIdx {
            if a == 0 {
                a += 1
            }
            if a == size {
                a -= 1
            }
        }

        if b == seedIdx {
            if b == 0 {
                b += 1
            }
            if b == size {
                b -= 1
            }
        }

        if a == b {
            a = Int(size / 2)
        }

        // XOR a and b with the seed
        self[a] = self[a] ^ seed
        self[b] = self[b] ^ seed
    }
}
