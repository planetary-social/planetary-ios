//
//  SecretsServiceAdapterTests.swift
//  
//
//  Created by Martin Dutra on 8/12/21.
//

import XCTest
@testable import Secrets

final class SecretsServiceAdapterTests: XCTestCase {

    private var service: SecretsServiceAdapter!

    override func setUp() {
        service = SecretsServiceAdapter(bundle: .module)
    }

    func testGet() {
        let expectedValue = "posthog-key"
        XCTAssertEqual(service.get(key: "posthog"), expectedValue)
    }

    func testGetWhenKeyIsNotFound() {
        XCTAssertNil(service.get(key: "unknownkey"))
    }

    func testGetWhenKeyIsFoundButEmpty() {
        XCTAssertNil(service.get(key: "bugsnag"))
    }

    func testGetWhenPlistDoesntExist() {
        service = SecretsServiceAdapter(bundle: .main)
        XCTAssertNil(service.get(key: "posthog"))
    }
}
