//
//  GoBotIntegrationTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// Warning: running these test will delete the database on whatever device they execute on.
class GoBotIntegrationTests: XCTestCase {
    
    var sut: GoBot!
    var workingDirectory: String!
    let fm = FileManager.default

    override func setUpWithError() throws {
        // We should refactor GoBot to use a configurable directory, so we don't clobber existing data every time we
        // run the unit tests. For now this will have to do.
        workingDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!
            .appending("/FBTT")

        // start fresh
        do { try fm.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }

        sut = GoBot()
        let loginExpectation = self.expectation(description: "login")
        sut.login(network: botTestNetwork, hmacKey: botTestHMAC, secret: botTestsKey) {
            error in
            defer { loginExpectation.fulfill() }
            XCTAssertNil(error)
        }
        self.wait(for: [loginExpectation], timeout: 10)

        let nicks = ["alice"]
        for n in nicks {
            try GoBotOrderedTests.shared.testingCreateKeypair(nick: n)
        }
    }

    override func tearDownWithError() throws {
        try fm.removeItem(atPath: workingDirectory)
    }

    /// Verifies that we can correctly refresh the `ViewDatabase` from the go-ssb log even after `publish` has copied
    /// some posts with a greater sequence number into `ViewDatabase` already.
    func testRefreshGivenPublish() throws {
        // Arrange
        for i in 0..<10 {
            _ = sut.testingPublish(as: "alice", content: Post(text: "Alice \(i)"))
        }
        
        // Act
        let postExpectation = self.expectation(description: "post published")
        let bobPost = Post(
            branches: nil,
            root: nil,
            text: "Bob 0")
        sut.publish(content: bobPost, completionQueue: .main) { messageID, error in
            XCTAssertNotNil(messageID)
            XCTAssertNil(error)
            postExpectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
        
        let refreshExpectation = self.expectation(description: "refresh completed")
        sut.refresh(load: .long, queue: .main) { error, _ in
            XCTAssertNil(error)
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
        
        // Assert
        XCTAssertEqual(sut.statistics.repo.messageCount, 11)
        XCTAssertEqual(sut.statistics.repo.numberOfPublishedMessages, 1)
        XCTAssertEqual(try sut.database.messageCount(), 11)
    }
    
}
