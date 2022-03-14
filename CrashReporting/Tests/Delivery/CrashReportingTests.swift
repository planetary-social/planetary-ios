//
//  MonitorTests.swift
//
//
//  Created by Martin Dutra on 24/11/21.
//

import XCTest
@testable import CrashReporting

final class CrashReportingTests: XCTestCase {

    private var service: CrashReportingServiceMock!
    private var crashReporting: CrashReporting!

    override func setUp() {
        service = CrashReportingServiceMock()
        crashReporting = CrashReporting(service: service)
    }

    func testIdentify() {
        crashReporting.identify(identifier: "user hash",
                                name: "user name",
                                networkKey: "network key",
                                networkName: "network name")
        XCTAssertTrue(service.identified)
    }

    func testForget() {
        crashReporting.forget()
        XCTAssertTrue(service.forgot)
    }

    func testRecord() {
        crashReporting.record("message")
        XCTAssertTrue(service.recorded)
    }

    func testCrash() {
        crashReporting.crash()
        XCTAssertTrue(service.crashed)
    }

    func testReport() {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        crashReporting.reportIfNeeded(error: error)
        XCTAssertTrue(service.crashed)
    }


}
