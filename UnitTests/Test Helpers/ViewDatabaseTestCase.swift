//
//  ViewDatabaseTestCase.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 11/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// A test case that opens a temporary ViewDatabase for testing.
class ViewDatabaseTestCase: XCTestCase {

    var dbURL = URL(fileURLWithPath: "unset")
    var db = ViewDatabase()
    var testAuthor: Identity = DatabaseFixture.exampleFeed.identities[0]
    
    override func setUp() async throws {
        try await super.setUp()
        await db.close(andOptimize: false)

        // get random location for the new database.
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/ViewDatabaseTestCase/\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: dbURL, withIntermediateDirectories: true)

        // open DB
        let dbPath = dbURL.absoluteString.replacingOccurrences(of: "file://", with: "")
        try db.open(path: dbPath, user: testAuthor, maxAge: -.infinity)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await db.close(andOptimize: false)
    }
}
