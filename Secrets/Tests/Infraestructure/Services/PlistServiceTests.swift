//
//  File.swift
//  
//
//  Created by Martin Dutra on 6/12/21.
//

import XCTest
@testable import Secrets

final class PlistServiceTests: XCTestCase {

    private var service: PlistService!

    override func setUp() {
        service = PlistService(bundle: Bundle.module)
    }

    func testGet() {
        XCTAssertEqual(service.get(key: "posthog"), "posthog-key")
    }

    func testGetWhenKeyIsUnknown() {
        XCTAssertNil(service.get(key: "unknownkey"))
    }

}
