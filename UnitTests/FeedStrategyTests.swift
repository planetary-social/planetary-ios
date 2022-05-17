//
//  FeedStrategyTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 5/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable force_unwrapping function_body_length

/// Tests to make sure our `FeedStrategy`s fetch the posts we expect.
class FeedStrategyTests: XCTestCase {
    
    var tmpURL = URL(string: "unset")!
    var db = ViewDatabase()
    let testAuthor: Identity = DatabaseFixture.exampleFeed.identities[0]

    override func setUpWithError() throws {
        try super.setUpWithError()
        db.close()
        
        // get random location for the new db
        self.tmpURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/viewDBtest-feedFill2"))
        
        do {
            try FileManager.default.removeItem(at: self.tmpURL)
        } catch {
            // ignore - most likely not exists
        }
        
        try FileManager.default.createDirectory(at: self.tmpURL, withIntermediateDirectories: true)
        
        // open DB
        let dbPath = tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
        try db.open(path: dbPath, user: testAuthor, maxAge: -60 * 60 * 24 * 30 * 48)
    }
    
    override func tearDown() {
        super.tearDown()
        db.close()
    }

    func testPatchworkFeedStrategy() throws {
        let referenceDate: Double = 1_652_813_189_000 // May 17, 2022 in millis
        let receivedDate: Double = 1_652_813_515_000 // May 17, 2022 in millis
        let alice = DatabaseFixture.exampleFeed.identities[1]
        let bob = DatabaseFixture.exampleFeed.identities[2]
        
        let post0 = KeyValueFixtures.post(
            key: "%0",
            sequence: 0,
            timestamp: referenceDate + 0,
            receivedTimestamp: receivedDate,
            receivedSeq: 0,
            author: testAuthor
        )
        let follow1 = KeyValueFixtures.keyValue(
            key: "%1",
            sequence: 1,
            content: Content(from: Contact(contact: alice, blocking: false)),
            timestamp: referenceDate + 1,
            receivedTimestamp: receivedDate,
            receivedSeq: 1,
            author: testAuthor
        )
        let about2 = KeyValueFixtures.keyValue(
            key: "%2",
            sequence: 2,
            content: Content(from: About(about: alice, name: "Alice")),
            timestamp: referenceDate + 2,
            receivedTimestamp: receivedDate,
            receivedSeq: 2,
            author: alice
        )
        let post3 = KeyValueFixtures.post(
            key: "%3",
            sequence: 3,
            timestamp: referenceDate + 3,
            receivedTimestamp: receivedDate,
            receivedSeq: 3,
            author: testAuthor
        )
        let reply4 = KeyValueFixtures.keyValue(
            key: "%4",
            sequence: 4,
            content: Content(
                from: Post(branches: ["%0"], root: "%0", text: "reply")
            ),
            timestamp: referenceDate + 4,
            receivedTimestamp: receivedDate,
            receivedSeq: 4,
            author: bob
        )
        
        try db.fillMessages(msgs: [post0, follow1, about2, post3, reply4])
        
        let strategy = PatchworkAlgorithm()
        let proxy = try db.paginatedFeed(with: strategy)
        
        XCTAssertEqual(proxy.count, 3)
        XCTAssertEqual(proxy.keyValueBy(index: 0), post0)
        XCTAssertEqual(proxy.keyValueBy(index: 1), follow1)
        XCTAssertEqual(proxy.keyValueBy(index: 2), post3)
    }
}
