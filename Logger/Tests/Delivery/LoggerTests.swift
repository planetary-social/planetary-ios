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
        Log.shared.service = service
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

    // MARK: Static functions

    func testStaticOptional() {
        let error = NSError(domain: "domain", code: 1, userInfo: nil)
        _ = Log.optional(error, "test")
        XCTAssert(service.invokedOptional)
    }

    func testStaticOptionalFromResponse() throws {
        let error = NSError(domain: "domain", code: 1, userInfo: nil)
        let url = try XCTUnwrap(URL(string: "planetary.social"))
        let response = URLResponse(url: url,
                                   mimeType: nil,
                                   expectedContentLength: 2,
                                   textEncodingName: nil)
        Log.optional(error, from: response)
        XCTAssert(service.invokedUnexpected)
    }

    func testStaticDebug() {
        Log.debug("test")
        XCTAssert(service.invokedDebug)
    }

    func testStaticInfo() {
        Log.info("test")
        XCTAssert(service.invokedInfo)
    }

    func testStaticFatal() {
        Log.fatal(.apiError, "test")
        XCTAssert(service.invokedFatal)
    }

    func testStaticUnexpected() {
        Log.unexpected(.incorrectValue, "test")
        XCTAssert(service.invokedUnexpected)
    }

    func testStaticError() {
        Log.error("test")
        XCTAssert(service.invokedUnexpected)
    }

    func testStaticFileUrls() {
        XCTAssertEqual(Log.fileUrls, service.fileUrls)
    }
}
