//
//  Bundle+VersionTests.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
import XCTest
@testable import Support

class Bundle_VersionTests: XCTestCase {

    func testModuleBundle() {
        let bundle = Bundle.module
        XCTAssertEqual(bundle.version, "")
        XCTAssertEqual(bundle.build, "")
        XCTAssertEqual(bundle.versionAndBuild, " ()")
    }
}
