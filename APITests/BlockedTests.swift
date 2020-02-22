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

// scenario1: unblock works
class BlockedTests: XCTestCase {

    static var newSecret: Secret? = nil
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

        BlockedTests.bot.createSecret() {
            sec, err in
            XCTAssertNil(err)
            BlockedTests.newSecret = sec
        }
        self.wait()
        guard let newBotSecret = BlockedTests.newSecret else {
            XCTFail("no new secret")
            return
        }

        var called = false
        BlockedTests.bot.login(
            network: NetworkKey.integrationTests,
            hmacKey: HMACKey.integrationTests,
            secret: newBotSecret) {
            error in
            XCTAssertNil(error)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        for id in Identities.for(NetworkKey.integrationTests) {
            BlockedTests.bot.follow(id) {
                contact, err in
                XCTAssertNil(err)
                XCTAssertNotNil(contact)
            }
            self.wait()
        }

        // who are we?
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .long
        formatter.dateStyle = .short

        let aboutMe = About(
            about: newBotSecret.identity,
            name: "BlockedTest \(formatter.string(from: currentDateTime))")
        BlockedTests.bot.publish(content: aboutMe) {
            _, err in
            XCTAssertNil(err)
        }
        self.wait()

        // follow back
        TestAPI.shared.invitePubsToFollow(newBotSecret.identity) {
            success, error in
            XCTAssertNil(error)
            XCTAssertTrue(success)
        }
        self.wait()

        if !self.syncAndRefresh() { return }

        called = false
        BlockedTests.bot.feed(identity: Identities.testNet.pubs["integrationpub1"]!) {
            msgs, err in
            defer { called = true }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTAssertGreaterThan(BlockedTests.bot.statistics.repo.feedCount, 1, "didnt even get feed")
                XCTFail("Expected init message from pub")
                return
            }
            XCTAssertEqual(msgs[0].contentType, .post)
            XCTAssertTrue(msgs[0].value.content.post?.text.hasPrefix("Setup init:") ?? false)
        }
        self.wait()
        XCTAssertTrue(called)
    }

    // regression test
    func test000_setup2_regression_sync_then_logout() {
        BlockedTests.bot.sync() {
            err, ts, _ in
            XCTAssertNil(err)
            XCTAssertNotEqual(ts, 0)
        }
        usleep(150_000)

        BlockedTests.bot.logout() { XCTAssertNil($0) }
        self.wait()
    }

    func test001_followBadBot() {
        guard let sec = BlockedTests.newSecret else { XCTFail("bot setup failed"); return }

        // login again
        var called = false
        BlockedTests.bot.login(
            network: NetworkKey.integrationTests,
            hmacKey: HMACKey.integrationTests,
            secret: sec) {
            error in
            XCTAssertNil(error)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        called = false
        TestAPI.shared.blockedStart(sec.identity) {
            newid, err in
            defer { called = true }
            XCTAssertNil(err)
            if err != nil { return }
            BlockedTests.badBot = newid
        }
        self.wait()
        XCTAssertTrue(called)

        // sync to make sure we are fairly up to date
        if !self.syncAndRefresh() { return }

        called = false
        BlockedTests.bot.follow(BlockedTests.badBot) {
            _, err in
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        if !self.syncAndRefresh() { return }

        called = false
        BlockedTests.bot.feed(identity: BlockedTests.badBot) {
            msgs, err in
            defer { called = true }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTFail("no messages for feed")
                return
            }
            XCTAssertEqual(msgs.count, 20)
            XCTAssertEqual(msgs[0].contentType, .post)
            XCTAssertTrue(msgs[0].value.content.post?.text.hasPrefix("spam:") ?? false)
         }
         self.wait()
         XCTAssertTrue(called)
    }

    func test002_blockBadBot() {
        if BlockedTests.badBot == "@unset" { XCTFail("blocked bot start failed"); return }

        var called = false
        BlockedTests.bot.block(BlockedTests.badBot) {
            ref, err in
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        var postAfterBlock: MessageIdentifier = "%unset"
        BlockedTests.bot.publish(content: Post(text: "geeeeezuz why are people so bad?")) {
            ref, err in
            XCTAssertNil(err)
            postAfterBlock = ref
        }
        self.wait()
        XCTAssertNotEqual(postAfterBlock, "%unset")

        var latestSeq: Int = -1
        BlockedTests.bot.feed(identity: BlockedTests.bot.identity!) {
            msgs, err in
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTFail("should have the published msg")
                return
            }
            XCTAssertEqual(msgs[0].key, postAfterBlock)
            latestSeq = msgs[0].value.sequence
        }
        self.wait()
        if latestSeq == -1 { XCTFail("should have the published msg"); return }

        if !self.syncAndRefresh() { return }

        called = false
        TestAPI.shared.blockedBlocked(bot: BlockedTests.badBot,
                                   author: BlockedTests.bot.identity!,
                                      seq: latestSeq,
                                      ref: postAfterBlock)
        {
            err in
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        self.syncAndRefresh()

        // can't see posts now
        called = false
        BlockedTests.bot.feed(identity: BlockedTests.badBot) {
            msgs, err in
            defer { called = true }
            XCTAssertNotNil(err)
            XCTAssertEqual(msgs.count, 0)
            XCTAssertLessThan(msgs.count, 20, "did get new messages after block!")
        }
        self.wait()
        XCTAssertTrue(called)
    }

    func test003_unblockBadBot() {
        if BlockedTests.badBot == "@unset" { XCTFail("blocked bot start failed"); return }

        var called = false
        BlockedTests.bot.unblock(BlockedTests.badBot) {
            ref, err in
            XCTAssertNil(err)
            called = true
        }
        self.wait(for: 10)
        XCTAssertTrue(called)

        var unblockPostRef: MessageIdentifier = "%unset"
        BlockedTests.bot.publish(content: Post(text:"lets see if they improved")) {
            ref, err in
            XCTAssertNil(err)
            unblockPostRef = ref
        }
        self.wait()
        XCTAssertNotEqual(unblockPostRef, "%unset")

        if !self.syncAndRefresh() { return }

        // get the latest sequence from the test users feeds
        var latestSeq: Int = -1
        BlockedTests.bot.thread(rootKey: unblockPostRef) {
            root, replies, err in
            XCTAssertNil(err)
            guard let r = root else {
                XCTFail("no root message?!")
                return
            }
            latestSeq = r.value.sequence
        }
        self.wait()
        if latestSeq == -1 {
            XCTAssertGreaterThan(latestSeq, 0, "did not find posted message?!")
            return
        }

        // badBot receives new messages
        called = false
        TestAPI.shared.blockedUnblocked(bot: BlockedTests.badBot,
                                     author: BlockedTests.bot.identity!,
                                        seq: latestSeq,
                                        ref: unblockPostRef)
        {
            err in
            XCTAssertNil(err)
            called = true
        }
        self.wait(for: 10)
        XCTAssertTrue(called)

        // make sure we get the appoligy, too
        if !self.syncAndRefresh() { return }

        called = false
        BlockedTests.bot.feed(identity: BlockedTests.badBot) {
            msgs, err in
            defer { called = true }
            XCTAssertNil(err)
            XCTAssertNotEqual(msgs.count, 0, "should have some messages")
            XCTAssertGreaterThan(msgs.count, 20, "should also have the new messages")
        }
        self.wait()
        XCTAssertTrue(called)
    }

    func test999_unfollow_and_shutdown() {
        if BlockedTests.badBot == "@unset" { XCTFail("blocked bot start failed"); return }

        var called = false
        TestAPI.shared.blockedStop(bot: BlockedTests.badBot) {
            err in
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        called = false
        TestAPI.shared.letTestPubUnfollow(BlockedTests.newSecret!.identity) {
            worked, err in
            XCTAssertTrue(worked)
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        called = false
        BlockedTests.bot.logout {
            err in
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)
    }

    // very assertiv version of the UI bot extension
    @discardableResult
    func syncAndRefresh() -> Bool {
        var called = false
        BlockedTests.bot.sync() {
            error, _, _ in
            XCTAssertNil(error)
            called = true
        }
        self.wait(for: 15) // give content a bit more time to get down
        XCTAssertTrue(called, "sync did not finish in time")
        if !called {
            return false
        }


        // getting these self.wait() timeouts right is tricky
        // especially on CI where the load is absurd
        // if the wait expires without the block having fired, there usually is now
        called = false
        BlockedTests.bot.refresh() {
            error, _ in
            XCTAssertNil(error, "view refresh failed")
            called = true
        }
        // TODO: would be nice to abstract this into something that doesn't have static sleep
        // https://app.asana.com/0/914798787098068/1157895192494153/f
        self.wait(for: 10)
        XCTAssertTrue(called, "view refresh did not happen")
        return called
    }
}
