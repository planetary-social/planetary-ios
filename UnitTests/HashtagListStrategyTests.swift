//
//  HashtagListStrategyTests.swift
//  UnitTests
//
//  Created by Martin Dutra on 2/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// Tests to make sure our `FeedStrategy`s fetch the posts we expect.
class HashtagListStrategyTests: XCTestCase {

    var tmpURL = URL(fileURLWithPath: "unset")
    var db = ViewDatabase()
    let testAuthor: Identity = DatabaseFixture.exampleFeed.identities[0]

    override func setUpWithError() throws {
        try super.setUpWithError()
        db.close(andOptimize: false)

        // get random location for the new
        tmpURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/viewDBtest-feedFill2"))

        do {
            try FileManager.default.removeItem(at: tmpURL)
        } catch {
            // ignore - most likely not exists
        }

        try FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: true)

        // open DB
        let dbPath = tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
        try db.open(path: dbPath, user: testAuthor, maxAge: -60 * 60 * 24 * 30 * 48)
    }

    override func tearDown() {
        super.tearDown()
        db.close(andOptimize: false)
    }

    func testPopularHashtagsStrategy() throws {
        let referenceDate: Double = 1_652_813_189_000 // May 17, 2022 in millis
        let receivedDate: Double = 1_652_813_515_000 // May 17, 2022 in millis
        let author = testAuthor
        let createPost = { (sequence: Int, hashtag: Hashtag) in
            MessageFixtures.post(
                key: "%\(sequence)",
                sequence: sequence,
                timestamp: referenceDate,
                receivedTimestamp: receivedDate,
                receivedSeq: Int64(sequence),
                post: Post(hashtags: [hashtag], text: hashtag.string),
                author: author
            )
        }
        let mostPopularHashtag = Hashtag(name: "hashtag1")
        let secondMostPopularHashtag = Hashtag(name: "hashtag2")
        let thirdMostPopularHashtag = Hashtag(name: "hashtag3")
        let msgs = [
            createPost(0, secondMostPopularHashtag),
            createPost(1, secondMostPopularHashtag),
            createPost(2, mostPopularHashtag),
            createPost(3, mostPopularHashtag),
            createPost(4, mostPopularHashtag),
            createPost(5, thirdMostPopularHashtag)
        ]
        try db.fillMessages(msgs: msgs)
        let hashtags = try db.hashtags(with: PopularHashtagsAlgorithm())
        XCTAssertEqual(hashtags.count, 3)
        XCTAssertEqual(hashtags[0], mostPopularHashtag)
        XCTAssertEqual(hashtags[1], secondMostPopularHashtag)
        XCTAssertEqual(hashtags[2], thirdMostPopularHashtag)
    }
}
