//
//  BugsnagServiceTests.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import XCTest
import Bugsnag
import Secrets
@testable import CrashReporting

final class BugsnagServiceTests: XCTestCase {

    private var service: BugsnagService?

    override func setUp() {
        super.setUp()
        service = BugsnagService(keys: Keys(bundle: .module))
    }

    func testInit() {
        XCTAssertEqual(Bugsnag.breadcrumbs().first?.message, "Bugsnag loaded")
    }

    func testIdentify() throws {
        let expectedIdentifier = "user hash"
        let expectedName = "John Doe"
        let expectedNetworkKey = "network hash"
        let expectedNetworkName = "a test network"
        let identity = Identity(
            identifier: expectedIdentifier,
            name: expectedName,
            networkKey: expectedNetworkKey,
            networkName: expectedNetworkName
        )
        let service = try XCTUnwrap(service)
        service.identify(identity: identity)
        let user = Bugsnag.user()
        let metadata = Bugsnag.getMetadata(section: "network")
        XCTAssertEqual(user.id, expectedIdentifier)
        XCTAssertEqual(user.name, expectedName)
        XCTAssertEqual(metadata?.value(forKey: "key") as? String, expectedNetworkKey)
        XCTAssertEqual(metadata?.value(forKey: "name") as? String, expectedNetworkName)
    }

    func testForget() throws {
        let identity = Identity(
            identifier: "user hash",
            name: "John Doe",
            networkKey: "network hash",
            networkName: "a test network"
        )
        let service = try XCTUnwrap(service)
        service.identify(identity: identity)
        service.forget()
        let user = Bugsnag.user()
        let metadata = Bugsnag.getMetadata(section: "network")
        XCTAssertNil(user.id)
        XCTAssertNil(user.name)
        XCTAssertNil(metadata)
    }

    func testRecord() throws {
        let expectedBreadcrumb = "test"
        let service = try XCTUnwrap(service)
        service.record(expectedBreadcrumb)
        XCTAssertEqual(Bugsnag.breadcrumbs().last?.message, expectedBreadcrumb)
    }

    func testReport() throws {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        let service = try XCTUnwrap(service)
        service.report(error: error, metadata: nil)
        XCTAssertEqual(Bugsnag.breadcrumbs().last?.message, "NSError")
    }

    func testReportWithMetadata() throws {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        let service = try XCTUnwrap(service)
        service.report(error: error, metadata: ["key": "value"])
        XCTAssertEqual(Bugsnag.breadcrumbs().last?.message, "NSError")
    }

    func testReportWithAppLog() throws {
        let error = NSError(domain: "com.planetary.social", code: 407, userInfo: nil)
        let service = try XCTUnwrap(service)
        let expectedAppLog = "hello"
        service.onEventHandler = {
            return Logs(appLog: expectedAppLog, botLog: nil)
        }
        service.report(error: error, metadata: nil)
        XCTAssertEqual(Bugsnag.breadcrumbs().last?.message, "NSError")
    }

    func testReportWithBotLog() throws {
        let error = NSError(domain: "com.planetary.social", code: 407, userInfo: nil)
        let service = try XCTUnwrap(service)
        let expectedBotLog = "hello"
        service.onEventHandler = {
            return Logs(appLog: nil, botLog: expectedBotLog)
        }
        service.report(error: error, metadata: nil)
        XCTAssertEqual(Bugsnag.breadcrumbs().last?.message, "NSError")
    }
}
