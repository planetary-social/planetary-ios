//
//  BlobTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 3/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// Some integration tests for our Blob-handling code.
class BlobTests: XCTestCase {

    /// Verifies that we parse markdown image links in a post.
    func testMarkdownImageLink() throws {
        // Arrange
        let inlineBlob = "![image](&wXkgLeyJZVLUCb5D0TOty9kuTZ7ZTyZj1lIWoYeenxo=.sha256)"
        let expectedSubstringsAndRanges = [
            ("![image](&wXkgLeyJZVLUCb5D0TOty9kuTZ7ZTyZj1lIWoYeenxo=.sha256)", NSRange(location: 0, length: 62))
        ]

        // Act
        let substringsAndRanges = inlineBlob.blobSubstringsAndRanges()
        
        // Assert
        assertEqualSubstringsAndRanges(substringsAndRanges, expectedSubstringsAndRanges)
    }

    /// Verifies that we parse a markdown image link where the name of the image is empty.
    func testEmptyImageName() throws {
        XCTExpectFailure("This test is expected to fail until # is implemented")
        
        // Arrange
        let inlineBlob = "![](&wXkgLeyJZVLUCb5D0TOty9kuTZ7ZTyZj1lIWoYeenxo=.sha256)"
        let expectedSubstringsAndRanges = [
            ("![](&wXkgLeyJZVLUCb5D0TOty9kuTZ7ZTyZj1lIWoYeenxo=.sha256)", NSRange(location: 0, length: 58))
        ]
        
        // Act
        let substringsAndRanges = inlineBlob.blobSubstringsAndRanges()
        
        // Assert
        assertEqualSubstringsAndRanges(substringsAndRanges, expectedSubstringsAndRanges)
    }
    
    private func assertEqualSubstringsAndRanges(_ lhs: [(String, NSRange)], _ rhs: [(String, NSRange)]) {
        XCTAssertEqual(lhs.count, rhs.count)
        for (index, tuple) in lhs.enumerated() {
            let (blobIdentifier, range) = tuple
            let (expectedBlobIdentifier, expectedRange) = rhs[index]
            XCTAssertEqual(blobIdentifier, expectedBlobIdentifier)
            XCTAssertEqual(range, expectedRange)
        }
    }
}
