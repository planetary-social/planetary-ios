//
//  KeyMapperTests.swift
//  
//
//  Created by Martin Dutra on 8/12/21.
//

import Foundation
@testable import Secrets
import XCTest

final class KeyMapperTests: XCTestCase {

    private var mapper: KeyMapper!

    override func setUp() {
        mapper = KeyMapper()
    }

    func testAllKeys() {
        XCTAssertNotNil(mapper.map(key: .posthog))
        XCTAssertNotNil(mapper.map(key: .bugsnag))
        XCTAssertNotNil(mapper.map(key: .push))
    }

}
