//
//  LoggerServiceAdapterTests.swift
//  
//
//  Created by Martin Dutra on 1/12/21.
//

import XCTest
@testable import Logger

final class LoggerServiceAdapterTests: XCTestCase {

    private var fileLoggerService: FileLoggerServiceMock!
    private var loggerService: LoggerServiceAdapter!

    override func setUp() {
        fileLoggerService = FileLoggerServiceMock()
        loggerService = LoggerServiceAdapter(fileLoggerService: fileLoggerService)
    }

    func testDebug() {
        loggerService.debug("test")
        XCTAssertTrue(fileLoggerService.invokedDebug)
        XCTAssertEqual(fileLoggerService.lastLine, "LOG:DEBUG: test")
    }

    func testInfo() {
        loggerService.info("test")
        XCTAssert(fileLoggerService.invokedInfo)
        XCTAssertEqual(fileLoggerService.lastLine, "LOG:INFO: test")
    }

    func testOptional() {
        XCTAssertFalse(loggerService.optional(nil, "test"))
        XCTAssertFalse(fileLoggerService.invokedError)

        let error = NSError(domain: "domain", code: 1, userInfo: nil)
        XCTAssertTrue(loggerService.optional(error, "test"))
        XCTAssertTrue(fileLoggerService.invokedError)
        XCTAssertEqual(fileLoggerService.lastLine, "LOG:ERROR:test \(error.description)")
    }

    func testFatal() {
        loggerService.fatal("reason", "test")
        XCTAssertTrue(fileLoggerService.invokedError)
        XCTAssertEqual(fileLoggerService.lastLine, "LOG:FATAL:reason test")
    }

    func testUnexpected() {
        loggerService.unexpected("reason", "test")
        XCTAssertTrue(fileLoggerService.invokedError)
        XCTAssertEqual(fileLoggerService.lastLine, "LOG:UNEXPECTED:reason test")
    }

    func testFileUrls() {
        XCTAssertEqual(fileLoggerService.fileUrls, loggerService.fileUrls)
    }

}
