//
//  VerseAPITests.swift
//  FBTTAPITests
//
//  Created by Christoph on 8/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class VerseAPITests: XCTestCase {

    func test00_directoryIsOnline() {
        let expectation = self.expectation(description: "Get directory")

        VerseAPI.directory {
            persons, error in
            XCTAssertNil(error, "Directory should be online: \(String(describing: error))")
            XCTAssertTrue(persons.count > 0, "Directory should not be empty")
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 5)
    }
}
