//
//  IdentifierTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import XCTest

class IdentifierTests: XCTestCase {

    func test_algorithm() {
        XCTAssertTrue(Algorithm(fromRawValue: "ggmsg-v1") == Algorithm.ggfeedmsg)
        XCTAssertTrue(Algorithm(fromRawValue: "sha256") == Algorithm.sha256)
        XCTAssertFalse(Algorithm(fromRawValue: "sha25") == Algorithm.sha256)
        XCTAssertTrue(Algorithm(fromRawValue: "ggfeed-v1") == Algorithm.ggfeed)
        XCTAssertTrue(Algorithm(fromRawValue: "ed25519") == Algorithm.ed25519)
        XCTAssertFalse(Algorithm(fromRawValue: "d25519") == Algorithm.ed25519)
        XCTAssertTrue(Algorithm(fromRawValue: "") == Algorithm.unsupported)
        XCTAssertTrue("sha256".algorithm == .sha256)
        XCTAssertTrue("ed25519".algorithm == .ed25519)
        XCTAssertTrue("ggfeed-v1".algorithm == .ggfeed)
        XCTAssertTrue("".algorithm == .unsupported)
    }

    func test_sigil() {
        XCTAssertTrue("&1234567890".sigil == .blob)
        XCTAssertTrue("@1234567890".sigil == .feed)
        XCTAssertTrue("%1234567890".sigil == .message)
        XCTAssertTrue("".sigil == .unsupported)
    }

    func test_id() {
        XCTAssertTrue("%1234567890=.sha256".id == "1234567890=")
        XCTAssertTrue("%1234567890.=sha256".id == Identifier.unsupported)
        XCTAssertFalse("%1234567890.=sha256".isValidIdentifier)
    }
}
