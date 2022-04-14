//
//  Beta1MigrationTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 4/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable implicitly_unwrapped_optional

class Beta1MigrationTests: XCTestCase {
    
    var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        userDefaults = UserDefaults()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLaunchViewControllerTriggersMigration() {
//        let sut = LaunchViewController()
    }
}
