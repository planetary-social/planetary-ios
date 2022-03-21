//
//  MonitorTests.swift
//
//
//  Created by Martin Dutra on 24/11/21.
//

import XCTest
@testable import CrashReporting

final class CrashReportingTests: XCTestCase {

    private var service: CrashReportingServiceMock?
    private var crashReporting: CrashReporting?

    override func setUp() {
        super.setUp()
        let service = CrashReportingServiceMock()
        crashReporting = CrashReporting(service: service)
        self.service = service
    }

    func testIdentify() throws {
        let crashReporting = try XCTUnwrap(crashReporting)
        crashReporting.identify(
            identifier: "user hash",
            name: "user name",
            networkKey: "network key",
            networkName: "network name"
        )
        let service = try XCTUnwrap(service)
        XCTAssertTrue(service.identified)
    }

    func testForget() throws {
        let crashReporting = try XCTUnwrap(crashReporting)
        crashReporting.forget()
        let service = try XCTUnwrap(service)
        XCTAssertTrue(service.forgot)
    }

    func testRecord() throws {
        let crashReporting = try XCTUnwrap(crashReporting)
        crashReporting.record("message")
        let service = try XCTUnwrap(service)
        XCTAssertTrue(service.recorded)
    }

    func testCrash() throws {
        let crashReporting = try XCTUnwrap(crashReporting)
        crashReporting.crash()
        let service = try XCTUnwrap(service)
        XCTAssertTrue(service.crashed)
    }

    func testReport() throws {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        let crashReporting = try XCTUnwrap(crashReporting)
        crashReporting.reportIfNeeded(error: error)
        let service = try XCTUnwrap(service)
        XCTAssertTrue(service.crashed)
    }
}
