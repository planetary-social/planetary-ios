//
//  SecretsServiceAdapterTests.swift
//  
//
//  Created by Martin Dutra on 8/12/21.
//

import XCTest
@testable import Secrets

final class SecretsServiceAdapterTests: XCTestCase {

    private var bundleSecretsService: BundleSecretsServiceMock!
    private var service: SecretsServiceAdapter!

    override func setUp() {
        bundleSecretsService = BundleSecretsServiceMock()
        service = SecretsServiceAdapter(bundleSecretsService: bundleSecretsService)
    }

    func testGet() {
        let expectedValue = "tests"
        bundleSecretsService.value = expectedValue
        XCTAssertEqual(service.get(key: .posthog), expectedValue)
    }

    func testGetWhenKeyIsNotFound() {
        bundleSecretsService.value = nil
        XCTAssertNil(service.get(key: .posthog))
    }


}
