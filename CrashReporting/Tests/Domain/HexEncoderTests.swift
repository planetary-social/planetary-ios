//
//  HexEncoderTests.swift
//  
//
//  Created by Martin Dutra on 29/6/22.
//

@testable import CrashReporting
import Foundation
import XCTest

final class HexEncoderTests: XCTestCase {

    let encoder = HexEncoder()

    func testBasicStimuli() {
        let stimuli = "test"
        let expectedResult = "b5eb2d"
        let result = encoder.encode(string: stimuli)
        XCTAssertEqual(result, expectedResult)
    }
}
