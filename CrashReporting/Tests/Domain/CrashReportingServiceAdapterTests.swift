//
//  CrashReportingServiceAdapterTests.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import XCTest
@testable import CrashReporting

final class CrashReportingServiceAdapterTests: XCTestCase {

    private var apiService: APIServiceMock?
    private var service: CrashReportingServiceAdapter?
    private var logsBuilder: LogsBuilderMock?

    override func setUp() {
        super.setUp()
        let apiService = APIServiceMock()
        let logsBuilder = LogsBuilderMock()
        service = CrashReportingServiceAdapter(apiService, logger: LogMock(), logsBuilder: logsBuilder)
        self.apiService = apiService
        self.logsBuilder = logsBuilder
    }

    func testStart() throws {
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.started)
    }

    func testIdentify() throws {
        let identity = Identity(
            identifier: "user hash",
            name: "user name",
            networkKey: "network key",
            networkName: "network name"
        )
        let service = try XCTUnwrap(service)
        service.identify(identity: identity)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.identified)
    }

    func testForget() throws {
        let service = try XCTUnwrap(service)
        service.forget()
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.forgot)
    }

    func testRecord() throws {
        let service = try XCTUnwrap(service)
        service.record("message")
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.recorded)
    }

    func testReport() throws {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        let service = try XCTUnwrap(service)
        service.report(error: error, metadata: nil)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.crashed)
    }

    func testReportWithAppLog() throws {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        let service = try XCTUnwrap(service)
        let expectedAppLog = "Hello, world!\n"
        logsBuilder?.appLog = expectedAppLog
        service.report(error: error, metadata: nil)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.crashed)
        XCTAssertEqual(apiService.lastAttachedLogs?.appLog, expectedAppLog)
    }

    func testReportWithBotLog() throws {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        let service = try XCTUnwrap(service)
        let expectedBotLog = "hola"
        logsBuilder?.botLog = expectedBotLog
        service.report(error: error, metadata: nil)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.crashed)
        XCTAssertEqual(apiService.lastAttachedLogs?.botLog, expectedBotLog)
    }
}
