//
//  Beta1MigrationTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 4/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable implicitly_unwrapped_optional

class MockAppConfiguration: AppConfiguration {
    override func apply() {
        // no-op, don't mess with the keychain
    }
}

class XCTBlockExpectation: XCTestExpectation {
    var queue = DispatchQueue(label: "XCTBlockExpectationQueue", qos: .background)

    init(condition: @escaping () -> Bool) {
        super.init(description: "XCTBlockExpectation")
        waitForCondition(condition: condition)
    }

    func waitForCondition(condition: @escaping () -> Bool) {
        queue.async { [weak self] in
            if condition() {
                self?.fulfill()
            } else {
                self?.waitForCondition(condition: condition)
            }
        }
    }
}

class MockMigrationBot: GoBot {
    override var version: String {
        "beta2Test"
    }
    
    override class func databaseDirectory(for configuration: AppConfiguration) throws -> String {
        NSTemporaryDirectory()
            .appending("/PlanetaryUnitTests")
            .appending("/Beta1MigrationTests")
    }
}

class Beta1MigrationTests: XCTestCase {
    
    var userDefaults: UserDefaults!

    func testLaunchViewControllerTriggersMigration() {
        userDefaults = UserDefaults()
        let mockBot = MockMigrationBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())
        let appConfig = MockAppConfiguration(with: botTestsKey)
        appConfig.network = botTestNetwork
        appConfig.hmacKey = botTestHMAC
        appConfig.bot = mockBot
        let appController = AppController()
        let sut = LaunchViewController(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = sut.view
        
        // Assert
        let expectation = XCTBlockExpectation {
            self.userDefaults.bool(forKey: "StartedBeta1Migration") == true &&
            self.userDefaults.string(forKey: "GoBotDatabaseVersion") == "beta2Test"
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testLaunchViewControllerDoesNotTriggersMigrationOnFreshAccount() {
    }
}
