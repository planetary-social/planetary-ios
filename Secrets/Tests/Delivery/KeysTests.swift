//
//  SecretsTests.swift
//
//
//  Created by Martin Dutra on 24/11/21.
//

import XCTest
@testable import Secrets

final class SecretsTests: XCTestCase {

    private var service: SecretsServiceMock!
    private var secrets: Keys!

    override func setUp() {
        service = SecretsServiceMock()
        secrets = Keys(service: service)
    }

    func testGet() {
        let expectedValue = "tests"
        service.value = expectedValue
        XCTAssertEqual(secrets.get(key: .posthog), expectedValue)
    }

    func testInit() {
        secrets = Keys(bundle: .module)
        let expectedValue = "posthog-key"
        service.value = expectedValue
        XCTAssertEqual(secrets.get(key: .posthog), expectedValue)
    }
}
