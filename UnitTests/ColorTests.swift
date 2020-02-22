//
//  ColorTests.swift
//
//
//  Created by Christoph on 11/23/19.
//

import XCTest
import UIKit

class ColorTests: XCTestCase {

    func test_averageColor() {
        XCTAssertTrue(UIColor.black.image().averageColor()?.rgb == 0x000000)
        XCTAssertTrue(UIColor.white.image().averageColor()?.rgb == 0xFFFFFF)
        XCTAssertTrue(UIColor.red.image().averageColor()?.rgb == 0xFF0000)
        XCTAssertTrue(UIColor.green.image().averageColor()?.rgb == 0x00FF00)
        XCTAssertTrue(UIColor.blue.image().averageColor()?.rgb == 0x0000FF)
    }
}
