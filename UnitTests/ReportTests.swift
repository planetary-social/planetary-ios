//
//  ReportTests.swift
//  UnitTests
//
//  Created by Martin Dutra on 14/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

class ReportTests: XCTestCase {

    var tmpURL = URL(fileURLWithPath: "unset")
    var db = ViewDatabase()
    let testAuthor: Identity = DatabaseFixture.exampleFeed.identities[0]

    override func setUpWithError() throws {
        try super.setUpWithError()
        db.close()

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
        db.close()
    }

    func testRecentReports() throws {
        let referenceDate: Double = 1_652_813_189_000 // May 17, 2022 in millis
        let receivedDate: Double = 1_652_813_515_000 // May 17, 2022 in millis
        let alice = DatabaseFixture.exampleFeed.identities[1]
        let bob = DatabaseFixture.exampleFeed.identities[2]

        let about0 = KeyValueFixtures.keyValue(
            key: "%0",
            sequence: 0,
            content: Content(from: About(about: alice, name: "Alice")),
            timestamp: referenceDate,
            receivedTimestamp: receivedDate,
            receivedSeq: 0,
            author: alice
        )
        let about1 = KeyValueFixtures.keyValue(
            key: "%1",
            sequence: 1,
            content: Content(from: About(about: bob, name: "Bob")),
            timestamp: referenceDate + 10,
            receivedTimestamp: receivedDate,
            receivedSeq: 1,
            author: bob
        )
        let follow1 = KeyValueFixtures.keyValue(
            key: "%2",
            sequence: 2,
            content: Content(from: Contact(contact: testAuthor, following: true)),
            timestamp: referenceDate + 20,
            receivedTimestamp: receivedDate,
            receivedSeq: 2,
            author: alice
        )
        try db.fillMessages(msgs: [about0, about1, follow1])

        let feedMention1 = KeyValueFixtures.keyValue(
            key: "%3",
            sequence: 3,
            content: Content(from: Post(mentions: [Mention(link: testAuthor)], text: "Hey")),
            timestamp: referenceDate + 30,
            receivedTimestamp: receivedDate,
            receivedSeq: 3,
            author: bob
        )
        try db.fillMessages(msgs: [feedMention1])

        let reports = try db.reports()
        XCTAssertEqual(reports.count, 2)

        XCTAssertEqual(try db.countNumberOfReports(since: reports[1]), 1)

        XCTAssertEqual(try db.countNumberOfReports(since: reports[0]), 0)

        XCTAssertEqual(try db.countNumberOfUnreadReports(), 2)

        try db.markMessageAsRead(identifier: "%2")

        XCTAssertEqual(try db.countNumberOfUnreadReports(), 1)

        let firstReport = try XCTUnwrap(try db.report(for: "%3"))
        XCTAssertEqual(firstReport.reportType, .feedMentioned)

        let secondReport = try XCTUnwrap(try db.report(for: "%2"))
        XCTAssertEqual(secondReport.reportType, .feedFollowed)

    }
}
