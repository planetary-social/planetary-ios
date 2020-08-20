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

fileprivate let publishManyCount = 25

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

        var ex = self.expectation(description: "login")
        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            error in
            defer { ex.fulfill() }
            XCTAssertNil(error)
        }
        self.wait(for: [ex], timeout: 10)

        let nicks = ["alice", "barbara", "claire", "denise", "page"]
        do {
            for n in nicks {
                try GoBotTests.shared.testingCreateKeypair(nick: n)
            }
        } catch {
            XCTFail("create test keys failed: \(error)")
        }

        // calling login twice works too
        ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            loginErr in
            defer { ex.fulfill() }
            XCTAssertNil(loginErr)
        }
        self.wait(for: [ex], timeout: 10)
        
    }
    
    func test001_regression_tests() {
        // first, log out for things we shouldn't be able to do
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.logout() {
            XCTAssertNil($0)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        // make sure we can't sync
        for i in 1...20 {
            let ex = self.expectation(description: "\(#function) cant sync")
            let peers = Environment.Constellation.stars.map { $0.toPeer() }
            GoBotTests.shared.sync(queue: .main, peers: peers) {
                err, ts, numberOfMessages in
                XCTAssertNotNil(err, "try\(i): should get an error")
                XCTAssertEqual(ts, 0)
                XCTAssertEqual(numberOfMessages, 0)
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)
        }

        let exFirstStats = self.expectation(description: "\(#function)")
        GoBotTests.shared.statistics { statistics in
            // status only gives us -1
            XCTAssertEqual(statistics.repo.feedCount, -1)
            XCTAssertEqual(statistics.db.lastReceivedMessage, -3)
            XCTAssertEqual(statistics.repo.messageCount, -1)
            XCTAssertEqual(statistics.repo.lastHash, "")
            exFirstStats.fulfill()
        }
        self.wait(for: [exFirstStats], timeout: 10)

        // finally log in again
        let exAgain = self.expectation(description: "\(#function)")
        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            loginErr in
            XCTAssertNil(loginErr)
            exAgain.fulfill()
        }
        self.wait(for: [exAgain], timeout: 10)

        // has the test keys keys
        do {
            GoBotTests.pubkeys = try GoBotTests.shared.testingGetNamedKeypairs()
        } catch {
            XCTFail("create test keys failed: \(error)")
        }
        let names = ["alice", "barbara", "claire", "denise", "page"]
        XCTAssertEqual(GoBotTests.pubkeys.count, names.count)
        for n in names {
            XCTAssertNotNil(GoBotTests.pubkeys[n], "failed to find \(n) in pubkeys")
        }

        let exSecondStats = self.expectation(description: "\(#function)")
        GoBotTests.shared.statistics { statistics in
            // no messages yet
            XCTAssertEqual(statistics.repo.feedCount, 0)
            XCTAssertEqual(statistics.db.lastReceivedMessage, -1)
            XCTAssertEqual(statistics.repo.messageCount, 0)
            XCTAssertEqual(statistics.repo.lastHash, "")
            exSecondStats.fulfill()
        }
        self.wait(for: [exSecondStats], timeout: 10)
    }

    // MARK: simple publish
    func test006_publish_one() {
        var messageHash = ""
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.publish(content: Post(text: "hello world")) {
            newMsgID, publishErr in
            XCTAssertNil(publishErr)
            XCTAssertTrue(newMsgID.hasPrefix("%"))
            XCTAssertTrue(newMsgID.hasSuffix(Algorithm.ggfeedmsg.rawValue))
            messageHash = newMsgID
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
        
        let exStats = self.expectation(description: "\(#function)")
        GoBotTests.shared.statistics { statistics in
            XCTAssertEqual(statistics.db.lastReceivedMessage, 0)
            XCTAssertEqual(statistics.repo.messageCount, 1)
            XCTAssertEqual(statistics.repo.lastHash, messageHash)
            exStats.fulfill()
        }
        self.wait(for: [exStats], timeout: 10)
    }

    // TODO: turn me into a benchmark
    func test008_PublishMany() {
        for i in 1...publishManyCount {
            let ex = self.expectation(description: "publish \(i)")
            GoBotTests.shared.publish(content: Post(text: "hello test \(i)")) {
                newMsgID, publishErr in
                XCTAssertNil(publishErr)
                XCTAssertTrue(newMsgID.hasPrefix("%"))
                XCTAssertTrue(newMsgID.hasSuffix(Algorithm.ggfeedmsg.rawValue))
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)
        }
        
        GoBotTests.shared.testRefresh(self)

        let exStats = self.expectation(description: "\(#function)")
        GoBotTests.shared.statistics { statistics in
            XCTAssertEqual(statistics.db.lastReceivedMessage, 0+publishManyCount)
            XCTAssertEqual(statistics.repo.messageCount, 1+publishManyCount)
            exStats.fulfill()
        }
        self.wait(for: [exStats], timeout: 10)
    }

//    Commenting text as after block work makes the following tests to not work properly
//    Possibly race issues.

//    func test009_login_status_logout_loop() {
//        for it in 1...20 {
//            var ex = self.expectation(description: "login \(it)")
//            GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
//                error in
//                XCTAssertNil(error)
//                ex.fulfill()
//            }
//            self.wait(for: [ex], timeout: 10)
//
//            // trigger ssbBotStatus
//            // TODO: this maybe should be a loop on a seperate thread to simulate the peer widget
//            XCTAssertEqual(GoBotTests.shared.statistics.peer.count, 0, "\(it): conn count not zero")
//
//            ex = self.expectation(description: "logout \(it)")
//            GoBotTests.shared.logout() {
//                error in
//                XCTAssertNil(error)
//                ex.fulfill()
//            }
//            self.wait(for: [ex], timeout: 10)
//        }
//        // start again
//        let ex = self.expectation(description: "final login")
//        GoBotTests.shared.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
//            error in
//            XCTAssertNil(error)
//            ex.fulfill()
//        }
//        self.wait(for: [ex], timeout: 10)
//    }

    // MARK: abouts
    func test100_postAboutSelf() {
        let ex = self.expectation(description: "\(#function)")
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
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test101_ViewHasAboutSelf() {
        let ex = self.expectation(description: "\(#function)")
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, 1+publishManyCount+1)
        GoBotTests.shared.about(identity: botTestsKey.identity) {
            about, err in
            XCTAssertNotNil(about)
            XCTAssertNil(err)
            XCTAssertEqual(about?.name, "the bot")
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test102_testuserAbouts() {
        let nicks = ["alice", "barbara", "claire", "denise", "page"]
        for n in nicks {
            let abt = About(about: GoBotTests.pubkeys[n]!, name: n)
            _ = GoBotTests.shared.testingPublish(as: n, content: abt)
        }

        GoBotTests.shared.testRefresh(self)

        XCTAssertEqual(GoBotTests.shared.statistics.repo.feedCount, nicks.count + 1)
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, publishManyCount+2+nicks.count)

        for n in nicks {
            let ex = self.expectation(description: "\(#function)")
            GoBotTests.shared.about(identity: GoBotTests.pubkeys[n]!) {
                about, err in
                XCTAssertNil(err, "err for \(n)")
                XCTAssertNotNil(about, "no about for \(n)")
                XCTAssertEqual(about?.name, n, "wrong name for \(n)")
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)
        }
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
            "denise":  ["alice", "barbara", "claire"],
            "page":    [],
        ]
        for tcase in whoFollowsWho {
            for who in tcase.value {
                let contact = Contact(contact: GoBotTests.pubkeys[who]!, following: true)
                let ref = GoBotTests.shared.testingPublish(as: tcase.key, content: contact)
                XCTAssertTrue(ref.hasPrefix("%"))
                XCTAssertTrue(ref.hasSuffix("ggmsg-v1"))
            }
        }

        let ex = self.expectation(description: "\(#function) refresh")
        GoBotTests.shared.refresh(load: .short, queue: .main) {
            err, _ in
            XCTAssertNil(err, "refresh error!")
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        let nFollows = 6
        let extra = 2 + 5 // abouts
        XCTAssertEqual(GoBotTests.shared.statistics.repo.messageCount, publishManyCount+extra+nFollows)

        for tc in whoFollowsWho {
            let ex = self.expectation(description: "\(#function) follow \(tc)")
            GoBotTests.shared.follows(identity: GoBotTests.pubkeys[tc.key]!) {
                contacts, err in
                XCTAssertNil(err, "err for \(tc.key)")
                XCTAssertEqual(contacts.count, tc.value.count, "wrong number of follows for \(tc.key)")
                for nick in tc.value {
                    XCTAssertTrue(contacts.contains(GoBotTests.pubkeys[nick]!), "\(tc.key): \(nick) not in contacts")
                }
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)
        }

        // reverse lookup
        let whoIsFollowedByWho: [String: [String]] = [
                  "alice":   ["barbara", "denise"],
                  "barbara": ["alice", "denise"],
                  "claire":  ["alice", "denise"],
                  "denise":  [],
                  "page":    [],
              ]
        for tc in whoIsFollowedByWho {
            let ex = self.expectation(description: "\(#function) check \(tc)")
            GoBotTests.shared.followedBy(identity: GoBotTests.pubkeys[tc.key]!) {
                contacts, err in
                XCTAssertNil(err, "err for \(tc.key)")
                XCTAssertEqual(contacts.count, tc.value.count, "wrong number of follows for \(tc.key)")
                for nick in tc.value {
                    XCTAssertTrue(contacts.contains(GoBotTests.pubkeys[nick]!), "\(tc.key): \(nick) not in contacts")
                }
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)
        }
    }

    // MARK: various safty checks
    func test111_skip_unsupported_messages() {
        let currentCount = GoBotTests.shared.statistics.db.lastReceivedMessage

        let n = 6000 // batch size is 5k TODO: find a way to tweek the batch-size in testing mode
        for i in 1...n {
            let rawJSON = "{ \"type\": \"really-weird-unsupported-for-sure\", \"i\": \(i) }"
            _ = GoBotTests.shared.testingPublish(as: "denise", raw: rawJSON.data(using: .utf8)!)
        }

        let afterUnsupported = GoBotTests.shared.testingPublish(as: "denise", content: Post(text: "after lots of unsupported"))

        var ex = self.expectation(description: "\(#function) 1")
        GoBotTests.shared.refresh(load: .short, queue: .main) {
            err, _ in
            XCTAssertNil(err, "refresh error!")
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        // need two refresh calls to consume the whole batch
        ex = self.expectation(description: "\(#function) 2")
        GoBotTests.shared.refresh(load: .short, queue: .main) {
            err, _ in
            XCTAssertNil(err, "refresh error!")
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        XCTAssertNotEqual(GoBotTests.shared.statistics.db.lastReceivedMessage, currentCount, "still at the old level")
        XCTAssertGreaterThan(GoBotTests.shared.statistics.db.lastReceivedMessage, currentCount+n, "did not get all the messages")

        // make sure we got the supported message
        ex = self.expectation(description: "\(#function) 3")
        GoBotTests.shared.thread(rootKey: afterUnsupported) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertEqual(replies.count, 0)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    // MARK: notifications

    func test121_first_notification_empty() {
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.reports() {
            reports, err in
            XCTAssertNil(err)
            XCTAssertEqual(reports.count, 0)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test122_first_notification() {
        let followRef = GoBotTests.shared.testingPublish(
            as: "alice",
            content: Contact(contact: botTestsKey.identity, following: true))

        GoBotTests.shared.testRefresh(self)

        let ex = self.expectation(description: "\(#function) notify")
        GoBotTests.shared.reports() {
            reports, err in
            defer { ex.fulfill() }
            XCTAssertNil(err)
            guard reports.count == 1 else {
                XCTFail("expected 1 message in notification")
                return
            }
            XCTAssertEqual(reports[0].messageIdentifier, followRef)
            XCTAssertEqual(reports[0].keyValue.value.author, GoBotTests.pubkeys["alice"]!)
        }
        self.wait(for: [ex], timeout: 10)
    }

    // MARK: recent

    func test130_recent_empty() {
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, publishManyCount+1)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test131_recent_post_by_not_followed() {
        let newRef = GoBotTests.shared.testingPublish(
            as: "alice",
            content: Post(text: "hello, world!"))

        GoBotTests.shared.testRefresh(self)
        
        let rex = self.expectation(description: "\(#function)")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, publishManyCount+1)
            rex.fulfill()
        }
        self.wait(for: [rex], timeout: 10)
    }

    func test132_recent_follow_alice() {
        let ex1 = self.expectation(description: "1")
        let c = Contact(contact: GoBotTests.pubkeys["alice"]!, following: true)
        GoBotTests.shared.publish(content: c) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
            ex1.fulfill()
        }
        self.wait(for: [ex1], timeout: 10)
        
        GoBotTests.shared.testRefresh(self)
        
        let ex2 = self.expectation(description: "2")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, publishManyCount+1+1)
            guard let kv =  msgs.keyValueBy(index: 0) else { XCTFail("no message"); return }
            XCTAssertEqual(kv.value.author, GoBotTests.pubkeys["alice"]!)
            ex2.fulfill()
        }
        self.wait(for: [ex2], timeout: 10)
    }
    
    func test135_recent_paginated_feed() {
        // publish more so we have some to work with
        for i in 0...100 {
            let data = try! Post(text: "lots of spam posts \(i)").encodeToData()
            _ = GoBotTests.shared.testingPublish(as: "alice", raw: data)
        }
        GoBotTests.shared.testRefresh(self)
        
        let ex1 = self.expectation(description: "get proxy")
        var proxy: PaginatedKeyValueDataProxy = StaticDataProxy()
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["alice"]!) {
            p, err in
            XCTAssertNotNil(p)
            XCTAssertNil(err)
            proxy = p
            ex1.fulfill()
        }
        self.wait(for: [ex1], timeout: 10)

        // check we have the start (default is 10 messages pre-fetched)
        XCTAssertEqual(proxy.count, 102)
        XCTAssertNotNil(proxy.keyValueBy(index: 0))
        XCTAssertNotNil(proxy.keyValueBy(index: 9))
        XCTAssertNil(proxy.keyValueBy(index: 10))

        // fetch more
        proxy.prefetchUpTo(index: 50)
        sleep(1)
        XCTAssertNotNil(proxy.keyValueBy(index: 23))
        XCTAssertNotNil(proxy.keyValueBy(index: 50))
        XCTAssertNil(proxy.keyValueBy(index: 51))
        
        // simulate bunch of calls (de-bounce)
        proxy.prefetchUpTo(index: 60)
        proxy.prefetchUpTo(index: 70)
        proxy.prefetchUpTo(index: 80)
        sleep(1)
        XCTAssertNotNil(proxy.keyValueBy(index: 80))
        XCTAssertNil(proxy.keyValueBy(index: 81))
    }
    
    // fire another prefetch while one is in-flight and check for duplicates
    func test136_paginate_quickly() {
        var refs = [MessageIdentifier]()
        for i in 1...100 {
            let data = try! Post(text: "lots of spam posts \(i)").encodeToData()
            let newRef = GoBotTests.shared.testingPublish(as: "page", raw: data)
            refs.append(newRef)
            
        }
        GoBotTests.shared.testRefresh(self)
       
        let ex1 = self.expectation(description: "get proxy")
        var proxy: PaginatedKeyValueDataProxy = StaticDataProxy()
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["page"]!) {
            p, err in
            XCTAssertNotNil(p)
            XCTAssertNil(err)
            proxy = p
            ex1.fulfill()
        }
        self.wait(for: [ex1], timeout: 10)

        // check we have the start (default is 10 messages pre-fetched)
        XCTAssertEqual(proxy.count, 100)
        XCTAssertNotNil(proxy.keyValueBy(index: 0))
        XCTAssertNotNil(proxy.keyValueBy(index: 9))
        XCTAssertNil(proxy.keyValueBy(index: 10))
        
        // run two prefetches right after another
        proxy.prefetchUpTo(index: 40)
        usleep(130000) // prefetch debounce is 125ms
        proxy.prefetchUpTo(index: 50)
        usleep(130000) // prefetch debounce is 125ms
        proxy.prefetchUpTo(index: 60)
        sleep(1)
        
        for i in 0...59 {
            guard let kv = proxy.keyValueBy(index: i) else {
                XCTFail("expected idx \(i)")
                return
            }
            // profile view is most recent (last published) first
            let want = "lots of spam posts \(100-i)"
            XCTAssertEqual(kv.value.content.post?.text, want)
        }
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

        GoBotTests.shared.testRefresh(self)

        var ex = self.expectation(description: "\(#function) thread")
        var msgMaybe: KeyValue? = nil
        GoBotTests.shared.thread(rootKey: root) {
            rootMsg, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(rootMsg)
            XCTAssertEqual(rootMsg?.key, root)
            XCTAssertFalse(rootMsg?.metadata.isPrivate ?? true)
            XCTAssertEqual(replies.count, posts.count - 1)
            msgMaybe = rootMsg
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        guard let msg = msgMaybe else {
            XCTAssertNotNil(msgMaybe)
            return
        }

        // open the same thread but with the KeyValue method
        ex = self.expectation(description: "\(#function) ask k-v")
        GoBotTests.shared.thread(keyValue: msg) {
            rootMsg, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(rootMsg)
            XCTAssertEqual(rootMsg?.key, root)
            XCTAssertEqual(replies.count, posts.count - 1)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        GoBotTests.simpleThread = root
    }

    // MARK: blobs
    func test160_blobsAdd() {
        let ex = self.expectation(description: "\(#function)")
        let td = "foobar".data(using: .utf8)!
        GoBotTests.shared.addBlob(data: td) {
            (blob, err) in
            XCTAssertNil(err)
            XCTAssertTrue(blob.hasPrefix("&"))
            XCTAssertTrue(blob.hasSuffix(".sha256"))
            XCTAssertEqual("&w6uP8Tcg6K2QR905Rms8iXTlksL6OD1KOWBxTK7wxPI=.sha256", blob)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test161_blobsGet() {
        let ex = self.expectation(description: "\(#function)")
        let tref = BlobIdentifier("&w6uP8Tcg6K2QR905Rms8iXTlksL6OD1KOWBxTK7wxPI=.sha256")
        GoBotTests.shared.data(for: tref) {
            identifier, data, err in
            XCTAssertNotNil(data)
            XCTAssertNil(err)
            let td = String(bytes: data!, encoding: .utf8)
            XCTAssertEqual(td, "foobar")
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test162_postBlobsWithoutName() {
        var msgRef = MessageIdentifier("!!unset")

        let p = Post(text: "test post")
        let img = UIImage(color: .red)!

        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.publish(p, with: [img]) {
            ref, err in
            ex.fulfill()
            XCTAssertNil(err)
            msgRef = ref
        }
        self.wait(for: [ex], timeout: 10)
        

        let postedMsg = try! GoBotTests.shared.database.get(key: msgRef)
        guard let m = postedMsg.value.content.post?.mentions else { XCTFail("not a post?"); return }
        guard m.count == 1 else { XCTFail("no mentions?"); return }

        let b = m.asBlobs()
        guard b.count == 1 else { XCTFail("no blobs?"); return }

        XCTAssertNil(b[0].name)
    }
    
    func test163_storeBlob() {
        let ref = BlobIdentifier("&d2rP8Tcg6K2QR905Rms8iXTlksL6OD1KOWBxTK7wxPI=.sha256")
        
        var ex = self.expectation(description: "Get current blob")
        GoBotTests.shared.data(for: ref) { (_, data, error) in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
        
        let orangePixel = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/TQBcNTh/AAAACklEQVR4nGNiAAAABgADNjd8qAAAAABJRU5ErkJggg==",
                               options: .ignoreUnknownCharacters)!
        ex = self.expectation(description: "Store blob")
        GoBotTests.shared.store(data: orangePixel, for: ref) { _, error in
            XCTAssertNil(error)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
        
        ex = self.expectation(description: "Get new blob")
        GoBotTests.shared.data(for: ref) { (_, data, error) in
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    // MARK: private
    /* disabled until UI is updated to show and respond to them correctly
    func test170_private_from_alice() {
        GoBotTests.shared.testRefresh(self)
        
        var currentCount = -1
        var ex = self.expectation(description: "\(#function) first recent")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            currentCount = msgs.count
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
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

        GoBotTests.shared.testRefresh(self)

        // don't display private roots in recent (yet)
        ex = self.expectation(description: "\(#function) 2nd recent")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount)
            let allMsgs = msgs.getAllMessages()
            XCTAssertEqual(allMsgs.count, currentCount)
            XCTAssertFalse(allMsgs.contains { return $0.key == privRef })
            XCTAssertFalse(allMsgs.contains { return $0.key == privReply })
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        ex = self.expectation(description: "\(#function) thread")
        GoBotTests.shared.thread(rootKey: privRef) {
            root, msgs, err in
            defer { ex.fulfill() }
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertTrue(root?.metadata.isPrivate ?? false)
            XCTAssertEqual(root?.value.author, GoBotTests.pubkeys["alice"]!)
            XCTAssertEqual(msgs.count, 1)
            guard msgs.count > 0 else {
                XCTFail("expected at least one message. got \(msgs.count)")
                return
            }
            guard let kv0 = msgs.keyValueBy(index: 0) else {
                XCTFail("failed to get msg[0]")
                return
            }
            XCTAssertNotNil(kv0.key, privReply)
            XCTAssertEqual(kv0.value.author, GoBotTests.pubkeys["barbara"]!)
        }
        self.wait(for: [ex], timeout: 10)
    }
    */

    // MARK: hashtags
    func test180_postWithHashtags() {
        let ex = self.expectation(description: "\(#function)")
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
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    func test181_getMsgForNewPost() {
        let ex = self.expectation(description: "\(#function)")
        let tag = Hashtag(name:"helloWorld")
        GoBotTests.shared.posts(with: tag) {
            (msgs, err) in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, 1)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)
    }

    // MARK: Delete

    func test200_delete_own_message() {
        var currentCount = -1
        let ex1 = self.expectation(description: "\(#function) recent")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            currentCount = msgs.count
            ex1.fulfill()
        }
        self.wait(for: [ex1], timeout: 10)
        

        let p = Post(text: "whoops, i will not have wanted to post this!")
        var whoopsRef: MessageIdentifier = "unset"
        let ex2 = self.expectation(description: "\(#function) publish")
        GoBotTests.shared.publish(content: p) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
            whoopsRef = ref
            ex2.fulfill()
        }
        self.wait(for: [ex2], timeout: 10)
        
        let ex3 = self.expectation(description: "\(#function) publish 2")
        GoBotTests.shared.publish(content: Post(text: "yikes..!")) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
            ex3.fulfill()
        }
        self.wait(for: [ex3], timeout: 10)
        
        let ex4 = self.expectation(description: "\(#function) publish 3")
        GoBotTests.shared.publish(content: Post(text: "what have I done?!")) {
            ref, err in
            XCTAssertNotNil(ref)
            XCTAssertNil(err)
            ex4.fulfill()
        }
        self.wait(for: [ex4], timeout: 10)

        let ex5 = self.expectation(description: "\(#function) final recent")
        GoBotTests.shared.recent() {
            msgs, err in
            defer { ex5.fulfill() }
            guard msgs.count == currentCount+3 else {
                XCTFail("not enough messages: \(msgs.count)")
                return
            }
            XCTAssertNil(err)
            let allMsgs = msgs.getAllMessages()
            XCTAssertTrue(allMsgs.contains { return $0.key == whoopsRef })
            let xref = Dictionary(grouping: allMsgs, by: { $0.key })
            XCTAssertEqual(xref.filter { $1.count > 1 }.count, 0)
        }
        self.wait(for: [ex5], timeout: 10)
        

        let exDelete = self.expectation(description: "\(#function) delete")
        GoBotTests.shared.delete(message: whoopsRef) {
            err in
            XCTAssertNil(err)
            exDelete.fulfill()
        }
        self.wait(for: [exDelete], timeout: 10)
        

        // gone from recent
        let exGone = self.expectation(description: "\(#function) gone")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertEqual(msgs.count, currentCount+2)
            XCTAssertNil(err)
            exGone.fulfill()
        }
        self.wait(for: [exGone], timeout: 10)
        

        // gone from direct open
        let exThread = self.expectation(description: "\(#function) gone")
        GoBotTests.shared.thread(rootKey: whoopsRef) {
            root, replies, err in
            defer { exThread.fulfill() }
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
        self.wait(for: [exThread], timeout: 10)

        // TODO: gone from notifications?
    }

    func test201_delete_someone_elses_post() {
        // post offensive message
        let ughMsg = GoBotTests.shared.testingPublish(
            as: "denise",
            content: Post(text: "i dont know why but ****** YOU!"))
        
        GoBotTests.shared.testRefresh(self)

        // find message on their feed
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["denise"]!) {
            msgs, err in
            defer { ex.fulfill() }
            XCTAssertNil(err)
            XCTAssertTrue(msgs.getAllMessages().contains { return $0.key == ughMsg })
        }
        self.wait(for: [ex], timeout: 10)
        

        // user triggers delete of that message
        let exDelete = self.expectation(description: "\(#function) delete")
        GoBotTests.shared.delete(message: ughMsg) {
            err in
            XCTAssertNil(err)
            exDelete.fulfill()
        }
        self.wait(for: [exDelete], timeout: 10)
        

        // and now it's gone!
        let exGone = self.expectation(description: "\(#function) chek gone")
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["denise"]!) {
            msgs, err in
            defer { exGone.fulfill() }
            XCTAssertNil(err)
            XCTAssertFalse(msgs.getAllMessages().contains { return $0.key == ughMsg })
        }
        self.wait(for: [exGone], timeout: 10)
        
    }
    
    // MARK: block a user
    func test202_block_a_user() {
        let spamCount = 50
        var currentCount = -1
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            currentCount = msgs.count
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

        for i in 1...spamCount {
            _ = GoBotTests.shared.testingPublish(as: "denise", content: Post(text: "alice stinks \(i)"))
        }

        let exGetThread = self.expectation(description: "\(#function) chek gone")
        var replyCount = -1
        GoBotTests.shared.thread(rootKey: GoBotTests.simpleThread) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            replyCount = replies.count
            exGetThread.fulfill()
        }
        self.wait(for: [exGetThread], timeout: 10)
        XCTAssertGreaterThan(replyCount, 0)

        let offseniveReply = Post(
            branches: [GoBotTests.simpleThread],
            root: GoBotTests.simpleThread,
            text: "YOU ALL *******")
        let offseniveRef = GoBotTests.shared.testingPublish(as: "denise", content: offseniveReply)

        // let's see what they are up to
        let exFollow = self.expectation(description: "\(#function) follow")
        GoBotTests.shared.publish(content: Contact(contact: GoBotTests.pubkeys["denise"]!, following: true)) {
            ref, err in
            XCTAssertNil(err)
            XCTAssertNotNil(ref)
            exFollow.fulfill()
        }
        self.wait(for: [exFollow], timeout: 10)
        
        GoBotTests.shared.testRefresh(self)

        // see the stinks
        let exRecent = self.expectation(description: "\(#function) stinks")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount+spamCount+1)
            exRecent.fulfill()
        }
        self.wait(for: [exRecent], timeout: 10)
        
        
        // see the uglyness
        let exThread = self.expectation(description: "\(#function) ugly")
        GoBotTests.shared.thread(rootKey: GoBotTests.simpleThread) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertEqual(replyCount+1, replies.count) // one new post
            XCTAssertTrue(replies.getAllMessages().contains { kv in
                return kv.key == offseniveRef
            })
            exThread.fulfill()
        }
        self.wait(for: [exThread], timeout: 10)
        
        // decide they have to go
        let exBlock = self.expectation(description: "\(#function) block")
        GoBotTests.shared.block(GoBotTests.pubkeys["denise"]!) {
            ref, err in
            XCTAssertNil(err)
            XCTAssertNotNil(ref)
            exBlock.fulfill()
        }
        self.wait(for: [exBlock], timeout: 10)
        
        // back to normal
        let exClean = self.expectation(description: "\(#function) recent")
        GoBotTests.shared.recent() {
           msgs, err in
           XCTAssertNil(err)
           XCTAssertEqual(msgs.count, currentCount)
           exClean.fulfill()
        }
        self.wait(for: [exClean], timeout: 10)
        
        
        // feed is empty
        let exFeed = self.expectation(description: "\(#function) feed empty")
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["denise"]!) {
            msgs, err in
            defer { exFeed.fulfill() }
            XCTAssertNotNil(err)
            XCTAssertEqual(msgs.count, 0)
        }
        self.wait(for: [exFeed], timeout: 10)
        
        
        // their reply is no longer visable
        let exThreadGone = self.expectation(description: "\(#function) thread gone")
        GoBotTests.shared.thread(rootKey: GoBotTests.simpleThread) {
            root, replies, err in
            XCTAssertNil(err)
            XCTAssertNotNil(root)
            XCTAssertEqual(replyCount, replies.count)
            XCTAssertFalse(replies.getAllMessages().contains { return $0.key == offseniveRef })
            exThreadGone.fulfill()
        }
        self.wait(for: [exThreadGone], timeout: 10)

        // TODO: test they can't mention us
    }
    func test210_alice_posts_delete_request() {
        GoBotTests.shared.testRefresh(self)

        let ex1 = self.expectation(description: "\(#function) recent1")
        var currentCount:Int = -1
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertGreaterThan(msgs.count, 0)
            currentCount = msgs.count
            ex1.fulfill()
        }
        self.wait(for: [ex1], timeout: 10)
        XCTAssertGreaterThan(currentCount, 0)

        let mistakeRef = GoBotTests.shared.testingPublish(
            as: "alice",
            content: Post(text: "please make this go away!"))

        GoBotTests.shared.testRefresh(self)

        let ex2 = self.expectation(description: "\(#function) recent2")
        GoBotTests.shared.recent() {
            msgs, err in
            defer { ex2.fulfill() }
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount+1)
        }
        self.wait(for: [ex2], timeout: 10)

        // pick message and publish delete request
        
        let ex3 = self.expectation(description: "\(#function) feed")
        GoBotTests.shared.feed(identity: GoBotTests.pubkeys["alice"]!) {
            msgs, err in
            defer { ex3.fulfill() }
            XCTAssertNil(err)
            if msgs.count < 1 {
                XCTFail("need at least one message from alice!")
                return
            }

            guard let kv0 = msgs.keyValueBy(index: 0) else {
                XCTFail("failed to get msg[0]")
                return
            }

            XCTAssertEqual(kv0.key, mistakeRef)

            let delContent = DropContentRequest(
                sequence: UInt(kv0.value.sequence),
                    hash: mistakeRef)
            _ = GoBotTests.shared.testingPublish(
                as: "alice",
                content: delContent)
        }
        self.wait(for: [ex3], timeout: 10)

        GoBotTests.shared.testRefresh(self)

        // and now it's gone!
        let ex4 = self.expectation(description: "\(#function) recent3")
        GoBotTests.shared.recent() {
            msgs, err in
            XCTAssertNil(err)
            XCTAssertEqual(msgs.count, currentCount)
            ex4.fulfill()
        }
        self.wait(for: [ex4], timeout: 10)
        
    }
    
    // MARK: Everyone
    
    func test220_everyone_empty() {
        let ex = self.expectation(description: "\(#function)")
        GoBotTests.shared.everyone() {
            msgs, err in
            XCTAssertNil(err)
            // we should have 100 posts from page (as is the only one we don't follow)
            XCTAssertEqual(msgs.count, 100)
            ex.fulfill()
        }
        self.wait(for: [ex], timeout: 10)

    }

    // MARK: TODOS

    // check that we cant view the profile or threads of a user that blocks us

    // have test users mention master

    // test mention notification

    // test thread reply notification
}

// testing only functions on the Go side
fileprivate extension GoBot {
    func testRefresh(_ tc: XCTestCase) -> Void {
        let syncExpectation = tc.expectation(description: "Sync")
        let peers = Environment.Constellation.stars.map { $0.toPeer() }
        self.sync(queue: .main, peers: peers) {
            error, _, _ in
            XCTAssertNil(error)
            syncExpectation.fulfill()
        }
        tc.wait(for: [syncExpectation], timeout: 30)

        let refreshExpectation = tc.expectation(description: "Refresh")
        self.refresh(load: .short, queue: .main) {
            error, _ in
            XCTAssertNil(error, "view refresh failed")
            refreshExpectation.fulfill()
        }
        tc.wait(for: [refreshExpectation], timeout: 30)
    }
    
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

fileprivate extension PaginatedKeyValueDataProxy {
    func getAllMessages() -> KeyValues {
        self.prefetchUpTo(index: self.count-1)
        
        // TODO
        sleep(5)
        /* TODO: wait for prefetch
        let done = DispatchSemaphore(value: 0)
        _ = self.keyValueBy(index: self.count-1, late: {
            idx, _ in
            done.signal()
            print("prefetch done \(idx)")
        })

        print("waiting for prefetch")
        done.wait()
        */

        var kvs = KeyValues()
        for i in 0...self.count-1 {
            guard let kv = self.keyValueBy(index: i) else {
                XCTFail("failed to get item \(i) of \(self.count)")
                continue
            }
            kvs.append(kv)
        }
        XCTAssertEqual(kvs.count, self.count, "did not fetch all messages")
        let xref = Dictionary(grouping: kvs, by: { $0.key })
        XCTAssertEqual(xref.filter { $1.count > 1 }.count, 0, "found duplicate messages in view")
        return kvs
    }
}
