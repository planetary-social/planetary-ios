//
//  NetworkKeyTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 2/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class NetworkKeyTests: XCTestCase {

    func test_statics() {
        XCTAssertNotNil(NetworkKey.ssb)
        XCTAssertNotNil(NetworkKey.verse)
        XCTAssertNotNil(NetworkKey.planetary)
    }

    func test_valid() {

        // SSB default
        let key = NetworkKey(base64: "1KHLiKZvAvjbY1ziZEHMXawbCEIM6qwjCDm3VYRan/s=")
        XCTAssertNotNil(key)
        XCTAssertTrue(key == NetworkKey.ssb)
    }

    func test_invalid() {

        // odd number of characters
        var key = NetworkKey(base64: "KHLiKZvvjbY1ziEHMXawbCEIM6qwjCDm3VYRan/")
        XCTAssertNil(key)
        
        // too short (needs to be 32bytes)
        key = NetworkKey(base64: "VmVyc2UgQ29tbXVuaWNhdGlvbnMsIEluYy4=")
        XCTAssertNil(key)
    }
}
