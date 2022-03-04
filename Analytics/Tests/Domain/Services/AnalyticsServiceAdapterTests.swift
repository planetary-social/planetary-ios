//
//  AnalyticsServiceAdapterTests.swift
//  
//
//  Created by Martin Dutra on 13/12/21.
//

import Foundation
@testable import Analytics
import XCTest

class AnalyticsServiceAdapterTests: XCTestCase {

    private var apiService: APIServiceMock!
    private var service: AnalyticsServiceAdapter!

    override func setUp() {
        apiService = APIServiceMock()
        service = AnalyticsServiceAdapter(apiService: apiService)
    }

    func testIsEnabled() {
        XCTAssertTrue(service.isEnabled)
        apiService.enabled = false
        XCTAssertFalse(service.isEnabled)
    }

    func testIdentify() {
        service.identify(identity: Identity(identifier: "identifier", name: nil, network: "network"))
        XCTAssertTrue(apiService.identified)
    }

    func testOptIn() {
        service.optIn()
        XCTAssertTrue(apiService.optedIn)
        service.optOut()
        XCTAssertFalse(apiService.optedIn)
        service.optIn()
        XCTAssertTrue(apiService.optedIn)
    }

    func testForget() {
        service.forget()
        XCTAssertTrue(apiService.forgot)
    }

    func testTrack() {
        service.track(event: .did, element: .post, name: "test", params: nil)
        XCTAssertTrue(apiService.tracked)
        XCTAssertEqual(apiService.lastTrackedEvent, "did_post_test")
    }

    func testTrackWithParams() {
        service.track(event: .did, element: .post, name: "test", params: ["param": "value"])
        XCTAssertTrue(apiService.tracked)
    }

}
