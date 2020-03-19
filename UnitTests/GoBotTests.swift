//
//  GoBotTests.swift
//  UnitTests Selfhosted edition
//
//  This is a rewrite of GoBotAPITests.swift which doesn't need a fixtures file.
//
//  Created by H on 22.10.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

fileprivate let botTestsKey = Secret(from: """
{"curve":"ed25519","id":"@shwQGai09Tv+Pjbgde6lmhQhc34NURtP2iwnI0xsKtQ=.ggfeed-v1","private":"RdUdi8VQFb38R3Tyv9/iWZwRmCy1L1GfbR6JVrTLHkKyHBAZqLT1O/4+NuB17qWaFCFzfg1RG0/aLCcjTGwq1A==.ed25519","public":"shwQGai09Tv+Pjbgde6lmhQhc34NURtP2iwnI0xsKtQ=.ed25519"}
""")!
fileprivate let botTestNetwork = NetworkKey(base64: "4vVhFHLFHeyutypUO842SyFd5jRIVhAyiZV29ftnKSU=")!
fileprivate let botTestHMAC = HMACKey(base64: "1MQuQUGsRDyMyrFQQRdj8VVsBwn/t0bX7QQRQisMWjY=")!

fileprivate let publishManyCount = 300

class GoBotTests: XCTestCase {

    static var shared = GoBot()

    // filled by testingGetNamedKeypairs
    static var pubkeys: [String: Identity] = [:]

    // filled by first publish testsq
    static var simpleThread: MessageIdentifier = "%fake.unset"

    // MARK: login/logout (and test setup)
    func test000_setup() {
        let fm = FileManager.default

        let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!

        // start fresh
        do {
            try fm.removeItem(atPath: appSupportDir.appending("/FBTT"))
        } catch {
            print(error)
            print("removing previous failed - propbably not exists")
        }

        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            error in
            XCTAssertNil(error)
        }
        self.wait()

        let nicks = ["alice", "barbara", "claire", "denise"]
        do {
            for n in nicks {
                try GoBotTests.shared.testingCreateKeypair(nick: n)
            }
        } catch {
            XCTFail("create test keys failed: \(error)")
        }

        // calling login twice works too
        var called = false
        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            loginErr in
            XCTAssertNil(loginErr)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)
    }
    
    func test001_regression_tests() {
        // first, log out for things we shouldn't be able to do
        var called = false
        GoBotTests.shared.logout() {
            XCTAssertNil($0)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        // make sure we can't sync
        for i in 1...20 {
            called = false
            GoBotTests.shared.sync() {
                err, ts, numberOfMessages in
                XCTAssertNotNil(err, "try\(i): should get an error")
                XCTAssertEqual(ts, 0)
                XCTAssertEqual(numberOfMessages, 0)
                called = true
            }
            self.wait(for: 1)
            XCTAssertTrue(called, "try\(i): block wasnt called")
        }

        // status only gives us -1
        XCTAssertEqual(GoBotTests.shared.statistics.repo.feedCount, -1)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.lastReceivedMessage, -3)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, -1)

        // finally log in again
        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            loginErr in
            XCTAssertNil(loginErr)
        }
        self.wait()

        // has the test keys keys
        do {
            GoBotTests.pubkeys = try GoBotTests.shared.testingGetNamedKeypairs()
        } catch {
            XCTFail("create test keys failed: \(error)")
        }
        let names = ["alice", "barbara", "claire", "denise"]
        XCTAssertEqual(GoBotTests.pubkeys.count, names.count)
        for n in names {
            XCTAssertNotNil(GoBotTests.pubkeys[n], "failed to find \(n) in pubkeys")
        }

        // no messages yet
        XCTAssertEqual(GoBotTests.shared.statistics.repo.feedCount, 0)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.lastReceivedMessage, -1)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, 0)
    }

    // MARK: simple publish
    func test006_publish_one() {
        var called = false
        GoBotTests.shared.publish(content: Post(text: "hello world")) {
            newMsgID, publishErr in
            defer { called = true }
            XCTAssertNil(publishErr)
            XCTAssertTrue(newMsgID.hasPrefix("%"))
            XCTAssertTrue(newMsgID.hasSuffix(Algorithm.ggfeedmsg.rawValue))
        }
        self.wait(for: 3)
        XCTAssertTrue(called)

        XCTAssertEqual(GoBotTests.shared.statistics.repo.lastReceivedMessage, 0)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, 1)
    }

    func test008_PublishMany() {
        for i in 1...publishManyCount {
            GoBotTests.shared.publish(content: Post(text: "hello test \(i)")) {
                newMsgID, publishErr in
                XCTAssertNil(publishErr)
                XCTAssertTrue(newMsgID.hasPrefix("%"))
                XCTAssertTrue(newMsgID.hasSuffix(Algorithm.ggfeedmsg.rawValue))
            }
        }
        self.wait()

        var called = false
        GoBotTests.shared.refresh {
            err, _ in
            XCTAssertNil(err, "refresh error!")
            called = true
        }
        self.wait()
        XCTAssertTrue(called, "refresh not called")

        XCTAssertEqual(GoBotTests.shared.statistics.repo.lastReceivedMessage, 0+publishManyCount)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, 1+publishManyCount)
    }

    func test009_login_status_logout_loop() {
        for it in 1...20 {
            var called = false
            GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
                error in
                XCTAssertNil(error)
                called = true
            }
            self.wait()
            XCTAssertTrue(called, "\(it) login failed")

            // trigger ssbBotStatus
            // TODO: this maybe should be a loop on a seperate thread to simulate the peer widget
            XCTAssertEqual(GoBotTests.shared.statistics.peer.count, 0, "\(it): conn count not zero")

            called = false
            GoBotTests.shared.logout() {
                error in
                XCTAssertNil(error)
                called = true
            }
            self.wait()
            XCTAssertTrue(called, "\(it) logout failed")
        }
        // start again
        var called = false
        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            error in
            XCTAssertNil(error)
            called = true
        }
        self.wait()
        XCTAssertTrue(called, "last login failed")
    }

    // MARK: abouts
    func test100_postAboutSelf() {
        let a = About(
            about: botTestsKey.identity,
            name: "the bot",
            description: "just another test user",
            imageLink: "&foo=.sha256"
        )
        GoBotTests.shared.publish(content: a) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
        }
        self.wait()
    }

    func test101_ViewHasAboutSelf() {
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, 1+publishManyCount+1)
        GoBotTests.shared.about(identity: botTestsKey.identity) {
            about, err in
            XCTAssertNotNil(about)
            XCTAssertNil(err)
            XCTAssertEqual(about?.name, "the bot")
        }
        self.wait()
    }

    func test102_testuserAbouts() {
        let nicks = ["alice", "barbara", "claire", "denise"]
        for n in nicks {
            let abt = About(about: GoBotTests.pubkeys[n]!, name: n)
            _ = GoBotTests.shared.testingPublish(as: n, content: abt)
        }

        GoBotTests.shared.refresh {
            err, _ in
            XCTAssertNil(err, "refresh error!")
        }
        self.wait(for: 5)

        XCTAssertEqual(GoBotTests.shared.statistics.repo.feedCount, nicks.count + 1)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, publishManyCount+2+nicks.count)

        for n in nicks {
            GoBotTests.shared.about(identity: GoBotTests.pubkeys[n]!) {
                about, err in
                XCTAssertNil(err, "err for \(n)")
                XCTAssertNotNil(about, "no about for \(n)")
                XCTAssertEqual(about?.name, n, "wrong name for \(n)")
            }
        }
        self.wait()
    }

    // MARK: contacts (follows / blocks)

    func test110_testuserContacts() {
        // should have at least:
        // 1 friend (a<>b)
        // 1 follows only (a>c)
        // 1 only followed (c)

        let whoFollowsWho: [String: [String]] = [
            "alice":   ["barbara", "claire"],
            "barbara": ["alice"],
            "claire":  [],
            "denise":  ["alice", "barbara", "claire"]
        ]
        for tcase in whoFollowsWho {
            for who in tcase.value {
                let contact = Contact(contact: GoBotTests.pubkeys[who]!, following: true)
                let ref = GoBotTests.shared.testingPublish(as: tcase.key, content: contact)
                XCTAssertTrue(ref.hasPrefix("%"))
                XCTAssertTrue(ref.hasSuffix("ggmsg-v1"))
            }
        }

        GoBotTests.shared.refresh {
            err, _ in
            XCTAssertNil(err, "refresh error!")
        }
        self.wait(for: 5)

        let nFollows = 6
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, 1+publishManyCount+5+nFollows)

        for tc in whoFollowsWho {
            GoBotTests.shared.follows(identity: GoBotTests.pubkeys[tc.key]!) {
                contacts, err in
                XCTAssertNil(err, "err for \(tc.key)")
                XCTAssertEqual(contacts.count, tc.value.count, "wrong number of follows for \(tc.key)")
                for nick in tc.value {
                    XCTAssertTrue(contacts.contains(GoBotTests.pubkeys[nick]!), "\(tc.key): \(nick) not in contacts")
                }
            }
        }
        self.wait()

        // reverse lookup
        let whoIsFollowedByWho: [String: [String]] = [
                  "alice":   ["barbara", "denise"],
                  "barbara": ["alice", "denise"],
                  "claire":  ["alice", "denise"],
                  "denise":  []
              ]
        for tc in whoIsFollowedByWho {
            GoBotTests.shared.followedBy(identity: GoBotTests.pubkeys[tc.key]!) {
                contacts, err in
                XCTAssertNil(err, "err for \(tc.key)")
                XCTAssertEqual(contacts.count, tc.value.count, "wrong number of follows for \(tc.key)")
                for nick in tc.value {
                    XCTAssertTrue(contacts.contains(GoBotTests.pubkeys[nick]!), "\(tc.key): \(nick) not in contacts")
                }
            }
        }
        self.wait()
    }

    // MARK: various safty checks
    func test111_skip_unsupported_messages() {
        let currentCount = GoBotTests.shared.statistics.repo.lastReceivedMessage

        let n = 6000 // batch size is 5k TODO: find a way to tweek the batch-size in testing mode
        for i in 1...n {
            let rawJSON = "{ \"type\": \"really-weird-unsupported-for-sure\", \"i\": \(i) }"
            _ = GoBotTests.shared.testingPublish(as: "denise", raw: rawJSON.data(using: .utf8)!)
        }

        let afterUnsupported = GoBotTests.shared.testingPublish(as: "denise", content: Post(text: "after lots of unsupported"))

        var called = false
        GoBotTests.shared.refresh {
            err, _ in
            XCTAssertNil(err, "refresh error!")
            called = true
        }
        self.wait()
        XCTAssertTrue(called, "refresh not called")

        // need two refresh calls to consume the whole batch
        called = false
        GoBotTests.shared.refresh {
            err, _ in
            XCTAssertNil(err, "refresh error!")
            called = true
        }
        self.wait()
        XCTAssertTrue(called, "2nd refresh not called")

        XCTAssertNotEqual(GoBotTests.shared.statistics.repo.lastReceivedMessage, currentCount, "still at the old level")
        XCTAssertGreaterThan(GoBotTests.shared.statistics.repo.lastReceivedMessage, currentCount+n, "did not get all the messages")

        // make sure we got the supported message
        called = false
        GoBotTests.shared.thread(rootKey: afterUnsupported) {
            root, replies, err in
            defer { called = true }
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertEqual(replies.count, 0)
        }
        self.wait()
        XCTAssertTrue(called, "thread not called")
    }

    // MARK: notifications

    func test121_first_notification_empty() {
        GoBotTests.shared.notifications() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, 0)
        }
        self.wait()
    }

    func test122_first_notification() {
        let followRef = GoBotTests.shared.testingPublish(
            as: "alice",
            content: Contact(contact: botTestsKey.identity, following: true))

        GoBotTests.shared.refresh {
            err, _ in
            XCTAssertNil(err, "refresh error!")
        }
        self.wait()

        GoBotTests.shared.notifications() {
            msgs, err in
            XCTAssertNil(err)
            guard msgs.count == 1 else {
                XCTFail("expected 1 message in notification")
                return
            }
            XCTAssertEqual(msgs[0].key, followRef)
            XCTAssertEqual(msgs[0].value.author, GoBotTests.pubkeys["alice"]!)
        }
    }

    // MARK: recent

    func test130_recent_empty() {
        var called = false
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, publishManyCount+1)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)
    }

    func test131_recent_post_by_not_followed() {
        _ = GoBotTests.shared.testingPublish(
            as: "alice",
            content: Post(text: "hello, world!"))

        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()
        
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, publishManyCount+1)
        }
        self.wait()
    }

    func test132_recent_follow_alice() {
        let c = Contact(contact: GoBotTests.pubkeys["alice"]!, following: true)
        GoBotTests.shared.publish(content: c) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
        }
        self.wait()
        
        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()
        
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, publishManyCount+1+1)
            XCTAssertEqual(msgs[0].value.author, GoBotTests.pubkeys["alice"]!)
        }
        self.wait()
    }

    // MARK: threads
    func test140_threads_simple() {
        let posts = [
            ("alice", "hello, world!"),
            ("barbara", "hi alice! nice to meet you"),
            ("claire", "oh hi! nice to have you two here!"),
            ("alice", "oh wow! so many people!")
        ]
        var root: MessageIdentifier = "%fake.unset"
        var lastBranch: MessageIdentifier = "%fake.unset"
        for (i,p) in posts.enumerated() {
            if i == 0 {
                let ref = GoBotTests.shared.testingPublish(as: p.0, content: Post(text: p.1))
                root = ref
                lastBranch = ref
            } else {
                let post = Post(
                    branches: [lastBranch],
                    root: root,
                    text: p.1)
                lastBranch = GoBotTests.shared.testingPublish(as: p.0, content: post)
            }
        }

        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()

        var msgMaybe: KeyValue? = nil
        GoBotTests.shared.thread(rootKey: root) {
            rootMsg, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(rootMsg)
            XCTAssertEqual(rootMsg?.key, root)
            XCTAssertFalse(rootMsg?.metadata.isPrivate ?? true)
            XCTAssertEqual(replies.count, posts.count - 1)
            msgMaybe = rootMsg
        }
        self.wait()

        guard let msg = msgMaybe else {
            XCTAssertNotNil(msgMaybe)
            return
        }

        // open the same thread but with the KeyValue method
        GoBotTests.shared.thread(keyValue: msg) {
            rootMsg, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(rootMsg)
            XCTAssertEqual(rootMsg?.key, root)
            XCTAssertEqual(replies.count, posts.count - 1)
        }
        self.wait()

        GoBotTests.simpleThread = root
    }

    // MARK: blobs
    func test160_blobsAdd() {
        let td = "foobar".data(using: .utf8)!
        GoBotTests.shared.addBlob(data: td) {
            (blob, err) in
            XCTAssertNil(err)
            XCTAssertTrue(blob.hasPrefix("&"))
            XCTAssertTrue(blob.hasSuffix(".sha256"))
            XCTAssertEqual("&w6uP8Tcg6K2QR905Rms8iXTlksL6OD1KOWBxTK7wxPI=.sha256", blob)
        }
        self.wait()
    }

    func test161_blobsGet() {
        let tref = BlobIdentifier("&w6uP8Tcg6K2QR905Rms8iXTlksL6OD1KOWBxTK7wxPI=.sha256")
        GoBotTests.shared.data(for: tref) {
            identifier, data, err in
            XCTAssertNotNil(data)
            XCTAssertNil(err)
            let td = String(bytes: data!, encoding: .utf8)
            XCTAssertEqual(td, "foobar")
        }
        self.wait()
    }

    func test161_postBlobs() {
        var msgRef = MessageIdentifier("!!unset")

        let p = Post(text: "test post")
        let img = UIImage(color: .red)!

        var called = false
        GoBotTests.shared.publish(p, with: [img]) {
            ref, err in
            called = true
            XCTAssertNil(err)
            msgRef = ref
        }
        self.wait()
        XCTAssertTrue(called)

        let postedMsg = try! GoBotTests.shared.database.get(key: msgRef)
        guard let m = postedMsg.value.content.post?.mentions else { XCTFail("not a post?"); return }
        guard m.count == 1 else { XCTFail("no mentions?"); return }

        let b = m.asBlobs()
        guard b.count == 1 else { XCTFail("no blobs?"); return }

        XCTAssertNil(b[0].name)
    }

    // MARK: private
    func test170_private_from_alice() {
        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()
        var currentCount = -1
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            currentCount = msgs.count
        }
        self.wait()
        XCTAssertGreaterThan(currentCount, 0)
        
        let privRef = GoBotTests.shared.testingPublish(
            as: "alice",
            recipients: [botTestsKey.identity, GoBotTests.pubkeys["barbara"]!],
            content: Post(text: "hello, you two!")) // TODO: add recps

        let replyPost = Post( // TODO: add recps
            branches: [privRef],
            root: privRef,
            text: "this is a reply")
        let privReply = GoBotTests.shared.testingPublish(
            as: "barbara",
            recipients: [botTestsKey.identity, GoBotTests.pubkeys["alice"]!],
            content: replyPost)

        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()

        // don't display private roots in recent (yet)
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount)
        }
        self.wait()

        GoBotTests.shared.thread(rootKey: privRef) {
            root, msgs, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertTrue(root?.metadata.isPrivate ?? false)
            XCTAssertEqual(root?.value.author, GoBotTests.pubkeys["alice"]!)
            XCTAssertEqual(msgs.count, 1)
            XCTAssertNotNil(msgs[0].key, privReply)
            XCTAssertEqual(msgs[0].value.author, GoBotTests.pubkeys["barbara"]!)
        }
        self.wait()
    }

    // MARK: hashtags
    func test180_postWithHashtags() {
        let p = Post(
            blobs: nil,
            branches: nil,
            hashtags: [Hashtag(name: "helloWorld")],
            mentions: nil,
            root: nil,
            text: "test post with hashtags")
        GoBotTests.shared.publish(content: p) {
            (msg, err) in
            XCTAssertNil(err)
            XCTAssertNotNil(msg)
        }
        self.wait()
    }

    func test181_getMsgForNewPost() {
        let tag = Hashtag(name:"helloWorld")
        GoBotTests.shared.posts(with: tag) {
            (msgs, err) in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, 1)
        }
        self.wait()
    }

    // MARK: Delete

    func test200_delete_own_message() {
        var currentCount = -1
        var called = false
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            currentCount = msgs.count
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        let p = Post(text: "whoops, i will not have wanted to post this!")
        var whoopsRef: MessageIdentifier = "unset"
        GoBotTests.shared.publish(content: p) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
            whoopsRef = ref
        }
        self.wait()
        GoBotTests.shared.publish(content: Post(text: "yikes..!")) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
        }
        self.wait()
        GoBotTests.shared.publish(content: Post(text: "what have I done?!")) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
        }
        self.wait()

        called = false
        GoBotTests.shared.recent() {
            msgs, err in
            guard msgs.count == currentCount+3 else {
                XCTFail("not enough messages: \(msgs.count)")
                return
            }
            XCTAssertNil(err)
            XCTAssertEqual(msgs[2].key, whoopsRef)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        called = false
        GoBotTests.shared.delete(message: whoopsRef) {
            err in
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        // gone from recent
        called = false
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertEqual(msgs.count, currentCount+2)
            XCTAssertNil(err)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        // gone from direct open
        GoBotTests.shared.thread(rootKey: whoopsRef) {
            root, replies, err in
            XCTAssertNil(root)
            XCTAssertEqual(replies.count, 0)
            guard let e = err else {
                XCTAssertNotNil(err)
                return
            }
            if case ViewDatabaseError.unknownMessage(MessageIdentifier: let msg) = e {
                XCTAssertEqual(msg, whoopsRef)
            } else {
               XCTFail("wrong error type: \(e)")
            }
        }
        self.wait()

        // TODO: gone from notifications
    }

    func test201_delete_someone_elses_post() {
        // post offensive message
        let ughMsg = GoBotTests.shared.testingPublish(
            as: "denise",
            content: Post(text: "i dont know why but ****** YOU!"))
        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()

        // find message on their feed
        var called = false
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["denise"]!) {
            msgs, err in
            defer { called = true }
            XCTAssertNil(err)
            XCTAssertTrue(msgs.contains { return $0.key == ughMsg })
        }
        self.wait()
        XCTAssertTrue(called)

        // user triggers delete of that message
        called = false
        GoBotTests.shared.delete(message: ughMsg) {
            err in
            XCTAssertNil(err)
            called = true
        }
        XCTAssertTrue(called)

        // and now it's gone!
        called = false
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["denise"]!) {
            msgs, err in
            defer { called = true }
            XCTAssertNil(err)
            XCTAssertFalse(msgs.contains { return $0.key == ughMsg })
        }
        self.wait()
        XCTAssertTrue(called)
    }
    
    // MARK: block a user
    func test202_block_a_user() {
        let spamCount = 50
        var currentCount = -1
        var called = false
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            currentCount = msgs.count
            called = true
        }
        self.wait()
        XCTAssertTrue(called)

        
        for i in 1...spamCount {
            _ = GoBotTests.shared.testingPublish(as: "denise", content: Post(text: "alice stinks \(i)"))
        }

        var replyCount = -1
        GoBotTests.shared.thread(rootKey: GoBotTests.simpleThread) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            replyCount = replies.count
        }
        self.wait()
        XCTAssertGreaterThan(replyCount, 0)

        let offseniveReply = Post(
            branches: [GoBotTests.simpleThread],
            root: GoBotTests.simpleThread,
            text: "YOU ALL *******")
        let offseniveRef = GoBotTests.shared.testingPublish(as: "denise", content: offseniveReply)

        // let's see what they are up to
        GoBotTests.shared.publish(content: Contact(contact: GoBotTests.pubkeys["denise"]!, following: true)) {
            ref, err in
            XCTAssertNil(err)
            XCTAssertNotNil(ref)
        }
        self.wait()
        
        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()
        
        // see the stinks
        called = false
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount+spamCount+1)
            called = true
        }
        self.wait()
        XCTAssertTrue(called)
        
        // see the uglyness
        GoBotTests.shared.thread(rootKey: GoBotTests.simpleThread) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertEqual(replyCount+1, replies.count) // one new post
            XCTAssertTrue(replies.contains { kv in
                return kv.key == offseniveRef
            })
        }
        self.wait()
        
        // decide they have to go
        GoBotTests.shared.block(GoBotTests.pubkeys["denise"]!) {
            ref, err in
            XCTAssertNil(err)
            XCTAssertNotNil(ref)
        }
        self.wait()
        
        // back to normal
        called = false
        GoBotTests.shared.recent() {
           msgs, err in
           XCTAssertNil(err)
           XCTAssertEqual(msgs.count, currentCount)
           called = true
        }
        self.wait()
        XCTAssertTrue(called)
        
        // feed is empty
        called = false
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["denise"]!) {
            msgs, err in
            defer { called = true }
            XCTAssertNotNil(err)
            XCTAssertEqual(msgs.count, 0)
        }
        self.wait()
        XCTAssertTrue(called)
        
        // their reply is no longer visable
        GoBotTests.shared.thread(rootKey: GoBotTests.simpleThread) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertEqual(replyCount, replies.count)
            XCTAssertFalse(replies.contains { return $0.key == offseniveRef })
        }
        self.wait()

        // TODO: test they can't mention us
    }
    func test210_alice_posts_delete_request() {
        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()

        var currentCount:Int = -1
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertGreaterThan(msgs.count, 0)
            currentCount = msgs.count
        }
        self.wait()
        XCTAssertGreaterThan(currentCount, 0)

        let mistakeRef = GoBotTests.shared.testingPublish(
            as: "alice",
            content: Post(text: "please make this go away!"))

        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()

        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            let keys = msgs.map { return $0.key }
            XCTAssertEqual(msgs.count, currentCount+1, "keys: \(keys)")
        }
        self.wait()

        // pick message and publish delete request
        var called = false
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["alice"]!) {
            msgs, err in
            defer { called = true }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTFail("need at least one message from alice!")
                return
            }

            XCTAssertEqual(msgs[0].key, mistakeRef)

            let delContent = DropContentRequest(
                sequence: UInt(msgs[0].value.sequence),
                    hash: mistakeRef)
            _ = GoBotTests.shared.testingPublish(
                as: "alice",
                content: delContent)
        }
        self.wait()
        XCTAssertTrue(called)

        GoBotTests.shared.refresh { err, _ in XCTAssertNil(err, "refresh error!") }; self.wait()

        // and now it's gone!
        called=false
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount)
            called=true
        }
        self.wait()
        XCTAssertTrue(called)
    }

    // MARK: TODOS

    // check that we cant view the profile or threads of a user that blocks us

    // have test users mention master

    // test mention notification

    // test thread reply notification
}

// testing only functions on the Go side
fileprivate extension GoBot {
    func testingCreateKeypair(nick: String) throws {
        var err: Error? = nil
        nick.withGoString {
            let ok = ssbTestingMakeNamedKey($0)
            if ok != 0 {
                err = GoBotError.unexpectedFault("failed to create test key")
            }
        }

        if let e = err { throw e }
    }

    func testingGetNamedKeypairs() throws -> [String: Identity] {
        guard let cstr = ssbTestingAllNamedKeypairs() else {
            throw GoBotError.unexpectedFault("failed to load keypairs")
        }
        let data = String(cString: cstr).data(using: .utf8)!

        var pubkeys: [String: Identity] = [:] // map we want to return

        let json = try JSONSerialization.jsonObject(with: data, options: [])
        if let dictionary = json as? [String: Any] {
            for (name, val) in dictionary {
                pubkeys[name] = val as? Identity
            }
        }
        return pubkeys
    }

    func testingPublish(as nick: String, recipients: [Identity]? = nil, content: ContentCodable) -> MessageIdentifier {
        let c = try! content.encodeToData().string()!
        var identifier: MessageIdentifier? = nil
        nick.withGoString { goStrNick in
            c.withGoString { goStrContent in

                if let recps = recipients { // private mode
                    if recps.count < 1 {
                        XCTFail("need at least one recipient")
                        return
                    }
                    recps.joined(separator: ";").withGoString { recpsJoined in
                        guard let refCstr = ssbTestingPublishPrivateAs(goStrNick, goStrContent, recpsJoined) else {
                            XCTFail("private publish failed")
                            return
                        }
                        identifier = String(cString: refCstr)
                    }
                    return
                }

                // public mode
                guard let refCstr = ssbTestingPublishAs(goStrNick, goStrContent) else {
                    XCTFail("publish failed!")
                    return
                }

                identifier = String(cString: refCstr)
            }
        }
        let id = identifier!
        XCTAssertTrue(id.hasPrefix("%"))
        XCTAssertTrue(id.hasSuffix("ggmsg-v1"))
        print(c)
        return id
    }

    func testingPublish(as nick: String, raw: Data) -> MessageIdentifier {
        let content = raw.string()!
        var identifier: MessageIdentifier? = nil
        nick.withGoString { goStrNick in
            content.withGoString { goStrContent in

                guard let refCstr = ssbTestingPublishAs(goStrNick, goStrContent) else {
                    XCTFail("raw publish failed!")
                    return
                }

                identifier = String(cString: refCstr)
            }
        }
        guard let id = identifier else {
            XCTFail("no identifier from raw publish")
            return "%publish-failed.wrong"
        }
        XCTAssertTrue(id.hasPrefix("%"))
        XCTAssertTrue(id.hasSuffix("ggmsg-v1"))
        return id
    }
}

fileprivate extension UIImage {
  convenience init?(color: UIColor, size: CGSize = CGSize(width: 5, height: 5)) {
    let rect = CGRect(origin: .zero, size: size)
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    color.setFill()
    UIRectFill(rect)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard let cgImage = image?.cgImage else { return nil }
    self.init(cgImage: cgImage)
  }
}
