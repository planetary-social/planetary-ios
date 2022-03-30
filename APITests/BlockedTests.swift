//
//  BlockedTests.swift
//  APITests
//
//  Created by H on 26.11.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

// MARK: TODO

/* scenario2: blocked contact doesn't see the posts from the author of the block
 * TODO: add tests to the view/bot (local) unit tests, that the UI/ViewDB doesn't expose content from the block author
 */

// TODO: fix pub setup

// scenario1: unblock works
class BlockedTests: XCTestCase {

    static var newSecret: Secret?
    static var bot: Bot = GoBot()

    static var badBot: Identity = "@unset"

    // MARK: login and test setup
    func test000_setup1_login_and_onboard() {
        let fm = FileManager.default

        let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!

        // start fresh
        do {
            try fm.removeItem(atPath: appSupportDir.appending("/FBTT"))
        } catch {
            print(error)
            print("removing previous failed - propbably not exists")
        }

        let createSecretExpectation = self.expectation(description: "Create secret")
        BlockedTests.bot.createSecret {
            sec, err in
            XCTAssertNil(err)
            BlockedTests.newSecret = sec
            createSecretExpectation.fulfill()
        }
        self.wait(for: [createSecretExpectation], timeout: 30)

        guard let newBotSecret = BlockedTests.newSecret else {
            XCTFail("no new secret")
            return
        }

        let loginExpectation = self.expectation(description: "Login")
        BlockedTests.bot.login(
            network: NetworkKey.integrationTests,
            hmacKey: HMACKey.integrationTests,
            secret: newBotSecret) {
            error in
            XCTAssertNil(error)
                loginExpectation.fulfill()
        }
        self.wait(for: [loginExpectation], timeout: 30)

        var followExpectations = [XCTestExpectation]()
        for id in Identities.for(NetworkKey.integrationTests) {
            let expectation = self.expectation(description: "Follow \(id)")
            BlockedTests.bot.follow(id) {
                contact, err in
                XCTAssertNil(err)
                XCTAssertNotNil(contact)
                expectation.fulfill()
            }
            followExpectations.append(expectation)
        }
        self.wait(for: followExpectations, timeout: 30)

        // who are we?
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .long
        formatter.dateStyle = .short

        let aboutMe = About(
            about: newBotSecret.identity,
            name: "BlockedTest \(formatter.string(from: currentDateTime))")

        let publishExpectation = self.expectation(description: "Publish about")
        BlockedTests.bot.publish(content: aboutMe) {
            _, err in
            XCTAssertNil(err)
            publishExpectation.fulfill()
        }
        self.wait(for: [publishExpectation], timeout: 30)

        // follow back
        let followBackExpectation = self.expectation(description: "Follow back")
        TestAPI.shared.invitePubsToFollow(newBotSecret.identity) {
            success, error in
            XCTAssertNil(error)
            XCTAssertTrue(success)
            followBackExpectation.fulfill()
        }
        self.wait(for: [followBackExpectation], timeout: 30)

        if !self.syncAndRefresh() { return }

        let feedExpectation = self.expectation(description: "Fetch feed")
        BlockedTests.bot.feed(identity: Identities.testNet.pubs["integrationpub1"]!) {
            msgs, err in
            defer { feedExpectation.fulfill() }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTAssertGreaterThan(BlockedTests.bot.statistics.repo.feedCount, 1, "didnt even get feed")
                XCTFail("Expected init message from pub")
                return
            }
            XCTAssertEqual(msgs[0].contentType, .post)
            XCTAssertTrue(msgs[0].value.content.post?.text.hasPrefix("Setup init:") ?? false)
        }
        self.wait(for: [feedExpectation], timeout: 30)
    }

    // regression test
    func test000_setup2_regression_sync_then_logout() {
        let syncExpectation = self.expectation(description: "Sync")
        BlockedTests.bot.sync {
            err, ts, _ in
            XCTAssertNil(err)
            XCTAssertNotEqual(ts, 0)
            syncExpectation.fulfill()
        }
        self.wait(for: [syncExpectation], timeout: 30)

        let logoutExpectation = self.expectation(description: "Logout")
        BlockedTests.bot.logout {
            XCTAssertNil($0)
            logoutExpectation.fulfill()
        }
        self.wait(for: [logoutExpectation], timeout: 30)
    }

    func test001_followBadBot() {
        guard let sec = BlockedTests.newSecret else { XCTFail("bot setup failed"); return }

        // login again
        var loginExpectation = self.expectation(description: "Login")
        BlockedTests.bot.login(
            network: NetworkKey.integrationTests,
            hmacKey: HMACKey.integrationTests,
            secret: sec) {
            error in
                XCTAssertNil(error)
                loginExpectation.fulfill()
        }
        self.wait(for: [loginExpectation], timeout: 30)

        var startExpectation = self.expectation(description: "Start")
        TestAPI.shared.blockedStart(sec.identity) {
            newid, err in
            defer { startExpectation.fulfill() }
            XCTAssertNil(err)
            if err != nil { return }
            BlockedTests.badBot = newid
        }
        self.wait(for: [startExpectation], timeout: 30)

        // sync to make sure we are fairly up to date
        if !self.syncAndRefresh() { return }

        var followExpectation = self.expectation(description: "Follow")
        BlockedTests.bot.follow(BlockedTests.badBot) {
            _, err in
            XCTAssertNil(err)
            followExpectation.fulfill()
        }
        self.wait(for: [followExpectation], timeout: 30)

        if !self.syncAndRefresh() { return }

        var feedExpectation = self.expectation(description: "Fetch feed")
        BlockedTests.bot.feed(identity: BlockedTests.badBot) {
            msgs, err in
            defer { feedExpectation.fulfill() }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTFail("no messages for feed")
                return
            }
            XCTAssertEqual(msgs.count, 20)
            XCTAssertEqual(msgs[0].contentType, .post)
            XCTAssertTrue(msgs[0].value.content.post?.text.hasPrefix("spam:") ?? false)
        }
        self.wait(for: [feedExpectation], timeout: 30)
    }

    func test002_blockBadBot() {
        if BlockedTests.badBot == "@unset" { XCTFail("blocked bot start failed"); return }

        let blockExpectation = self.expectation(description: "Block")
        BlockedTests.bot.block(BlockedTests.badBot) {
            _, err in
            XCTAssertNil(err)
            blockExpectation.fulfill()
        }
        self.wait(for: [blockExpectation], timeout: 30)

        let publishExpectation = self.expectation(description: "Publish")
        var postAfterBlock: MessageIdentifier = "%unset"
        BlockedTests.bot.publish(content: Post(text: "geeeeezuz why are people so bad?")) {
            ref, err in
            XCTAssertNil(err)
            postAfterBlock = ref
            publishExpectation.fulfill()
        }
        self.wait(for: [publishExpectation], timeout: 30)
        XCTAssertNotEqual(postAfterBlock, "%unset")

        let feedExpectation = self.expectation(description: "Fetch feed")
        var latestSeq: Int = -1
        BlockedTests.bot.feed(identity: BlockedTests.bot.identity!) {
            msgs, err in
            defer { feedExpectation.fulfill() }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTFail("should have the published msg")
                return
            }
            XCTAssertEqual(msgs[0].key, postAfterBlock)
            latestSeq = msgs[0].value.sequence
        }
        self.wait(for: [feedExpectation], timeout: 30)
        if latestSeq == -1 { XCTFail("should have the published msg"); return }

        if !self.syncAndRefresh() { return }

        let blockedExpectation = self.expectation(description: "Blocked blocked")
        TestAPI.shared.blockedBlocked(bot: BlockedTests.badBot,
                                   author: BlockedTests.bot.identity!,
                                      seq: latestSeq,
                                      ref: postAfterBlock) {
            err in
            XCTAssertNil(err)
            blockedExpectation.fulfill()
        }
        self.wait(for: [blockedExpectation], timeout: 10)

        self.syncAndRefresh()

        // can't see posts now
        let emptyFeedExpectation = self.expectation(description: "Fetch empty feed")
        BlockedTests.bot.feed(identity: BlockedTests.badBot) {
            msgs, err in
            defer { emptyFeedExpectation.fulfill() }
            XCTAssertNotNil(err)
            XCTAssertEqual(msgs.count, 0)
            XCTAssertLessThan(msgs.count, 20, "did get new messages after block!")
        }
        self.wait(for: [emptyFeedExpectation], timeout: 30)
    }

    func test003_unblockBadBot() {
        if BlockedTests.badBot == "@unset" { XCTFail("blocked bot start failed"); return }

        let unblockExpectation = self.expectation(description: "Unblock")
        BlockedTests.bot.unblock(BlockedTests.badBot) {
            _, err in
            XCTAssertNil(err)
            unblockExpectation.fulfill()
        }
        self.wait(for: [unblockExpectation], timeout: 10)

        let publishExpectation = self.expectation(description: "Publish")
        var unblockPostRef: MessageIdentifier = "%unset"
        BlockedTests.bot.publish(content: Post(text: "lets see if they improved")) {
            ref, err in
            XCTAssertNil(err)
            unblockPostRef = ref
            publishExpectation.fulfill()
        }
        self.wait(for: [publishExpectation], timeout: 10)
        XCTAssertNotEqual(unblockPostRef, "%unset")

        if !self.syncAndRefresh() { return }

        // get the latest sequence from the test users feeds
        let threadExpectation = self.expectation(description: "Thread")
        var latestSeq: Int = -1
        BlockedTests.bot.thread(rootKey: unblockPostRef) {
            root, _, err in
            defer { threadExpectation.fulfill() }
            XCTAssertNil(err)
            guard let r = root else {
                XCTFail("no root message?!")
                return
            }
            latestSeq = r.value.sequence
        }
        self.wait(for: [threadExpectation], timeout: 30)
        if latestSeq == -1 {
            XCTAssertGreaterThan(latestSeq, 0, "did not find posted message?!")
            return
        }

        // badBot receives new messages
        let blockedExpectation = self.expectation(description: "Blocked unblocked")
        TestAPI.shared.blockedUnblocked(bot: BlockedTests.badBot,
                                     author: BlockedTests.bot.identity!,
                                        seq: latestSeq,
                                        ref: unblockPostRef) {
            err in
            XCTAssertNil(err)
            blockedExpectation.fulfill()
        }
        self.wait(for: [blockedExpectation], timeout: 10)

        // make sure we get the appoligy, too
        if !self.syncAndRefresh() { return }

        let feedExpectation = self.expectation(description: "Fetch feed")
        BlockedTests.bot.feed(identity: BlockedTests.badBot) {
            msgs, err in
            defer { feedExpectation.fulfill() }
            XCTAssertNil(err)
            XCTAssertNotEqual(msgs.count, 0, "should have some messages")
            XCTAssertGreaterThan(msgs.count, 20, "should also have the new messages")
        }
        self.wait(for: [feedExpectation], timeout: 10)
    }

    func test999_unfollow_and_shutdown() {
        if BlockedTests.badBot == "@unset" { XCTFail("blocked bot start failed"); return }

        let blockedExpectation = self.expectation(description: "Blocked stop")
        TestAPI.shared.blockedStop(bot: BlockedTests.badBot) {
            err in
            XCTAssertNil(err)
            blockedExpectation.fulfill()
        }
        self.wait(for: [blockedExpectation], timeout: 10)

        let unfollowExpectation = self.expectation(description: "Unfollow pub")
        TestAPI.shared.letTestPubUnfollow(BlockedTests.newSecret!.identity) {
            worked, err in
            XCTAssertTrue(worked)
            XCTAssertNil(err)
            unfollowExpectation.fulfill()
        }
        self.wait(for: [unfollowExpectation], timeout: 10)

        let logoutExpectation = self.expectation(description: "Logout")
        BlockedTests.bot.logout {
            err in
            XCTAssertNil(err)
            logoutExpectation.fulfill()
        }
        self.wait(for: [logoutExpectation], timeout: 10)
    }

    // very assertiv version of the UI bot extension
    @discardableResult
    func syncAndRefresh() -> Bool {
        let syncExpectation = self.expectation(description: "Sync")
        BlockedTests.bot.sync {
            error, _, _ in
            XCTAssertNil(error)
            syncExpectation.fulfill()
        }
        self.wait(for: [syncExpectation], timeout: 30)

        let refreshExpectation = self.expectation(description: "Refresh")
        BlockedTests.bot.refresh {
            error, _ in
            XCTAssertNil(error, "view refresh failed")
            refreshExpectation.fulfill()
        }
        self.wait(for: [refreshExpectation], timeout: 30)

        return true
    }
}
