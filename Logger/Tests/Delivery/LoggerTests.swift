//
//  LoggerTests.swift
//  
//
//  Created by Martin Dutra on 22/11/21.
//

import XCTest
@testable import Logger

final class LoggerTests: XCTestCase {

    private var service: LoggerServiceMock!
    private var logger: Log!

    override func setUp() {
        service = LoggerServiceMock()
        logger = Log(service: service)
    }

    func testOptional() {
        let error = NSError(domain: "domain", code: 1, userInfo: nil)
        _ = logger.optional(error, "test")
        XCTAssert(service.invokedOptional)
    }

    func testDebug() {
        logger.debug("test")
        XCTAssert(service.invokedDebug)
    }

    func testInfo() {
        logger.info("test")
        XCTAssert(service.invokedInfo)
    }

    func testFatal() {
        logger.fatal(.apiError, "test")
        XCTAssert(service.invokedFatal)
    }

    func testUnexpected() {
        logger.unexpected(.incorrectValue, "test")
        XCTAssert(service.invokedUnexpected)
    }

    func testFileUrls() {
        XCTAssertEqual(logger.fileUrls, service.fileUrls)
    }

}
