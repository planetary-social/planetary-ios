//
//  DefaultLogsBuilderTests.swift
//  
//
//  Created by Martin Dutra on 28/6/22.
//

import Foundation
@testable import CrashReporting
import XCTest

final class DefaultLogsBuilderTests: XCTestCase {

    let builder = DefaultLogsBuilder()

    var identity: Identity {
        Identity(identifier: "test", networkKey: "test", networkName: "test")
    }

    var logsPath: String {
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return appSupportDirs[0].appending("/FBTT/b5eb2d/GoSbot/debug")
    }

    override func setUp() async throws {
        try await super.setUp()
        try? FileManager.default.removeItem(atPath: logsPath)
        try FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true)
    }

    func testAppLog() {
        let logger = LogMock()
        let appLog = "Hello, world!\n"
        let logs = builder.build(logger: logger, identity: nil)
        XCTAssertEqual(logs.appLog, appLog)
    }

    func testBotLogWithoutFiles() throws {
        let logger = LogMock()
        let logs = builder.build(logger: logger, identity: identity)
        XCTAssertEqual(logs.botLog, nil)
    }

    func testBotLogWrongEncoding() throws {
        let logger = LogMock()
        let logs = builder.build(logger: logger, identity: identity)
        let botLog = "Hello, world!\n"
        FileManager.default.createFile(atPath: logsPath.appending("/1.txt"), contents: botLog.data(using: .utf16))
        XCTAssertEqual(logs.botLog, nil)
    }

    func testBotLogWithOneFile() throws {
        let logger = LogMock()
        let botLog = "Hello, world!\n"
        FileManager.default.createFile(atPath: logsPath.appending("/1.txt"), contents: botLog.data(using: .utf8))
        let logs = builder.build(logger: logger, identity: identity)
        XCTAssertEqual(logs.botLog, botLog)
    }

    func testBotLogWithTwoFiles() throws {
        let logger = LogMock()
        let identity = Identity(identifier: "test", networkKey: "test", networkName: "test")
        let botLog = "Hello, world!\n"
        FileManager.default.createFile(atPath: logsPath.appending("/1.txt"), contents: botLog.data(using: .utf8))
        FileManager.default.createFile(atPath: logsPath.appending("/2.txt"), contents: botLog.data(using: .utf8))
        let logs = builder.build(logger: logger, identity: identity)
        XCTAssertEqual(logs.botLog, botLog.appending("\n").appending(botLog))
    }
}
