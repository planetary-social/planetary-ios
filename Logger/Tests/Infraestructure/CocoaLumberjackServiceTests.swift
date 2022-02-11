//
//  CocoaLumberjackServiceTests.swift
//  
//
//  Created by Martin Dutra on 30/11/21.
//

import XCTest
@testable import Logger
import CocoaLumberjackSwift

final class CocoaLumberjackServiceTests: XCTestCase {

    private var service: CocoaLumberjackService!

    override func setUp() {
        asyncLoggingEnabled = false
        service = CocoaLumberjackService()
    }

    func testDebug() {
        service.debug("test")
        let lastLine = readLastLine()
        XCTAssertTrue(lastLine?.contains("test") ?? false)
    }

    func testInfo() {
        service.info("info")
        let lastLine = readLastLine()
        XCTAssertTrue(lastLine?.contains("info") ?? false)
    }

    func testError() {
        service.error("error")
        let lastLine = readLastLine()
        XCTAssertTrue(lastLine?.contains("error") ?? false)
    }

    func readLastLine() -> String? {
        guard let url = service.fileUrls.first else {
            return nil
        }
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            var lines = data.components(separatedBy: .newlines)
            lines.removeLast()
            return lines.last
        } catch {
            return nil
        }
    }
}
