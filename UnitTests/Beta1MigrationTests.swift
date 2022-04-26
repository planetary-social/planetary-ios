//
//  Beta1MigrationTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 4/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping

/// Tests for the "beta1" go-ssb migration. More info on this migration can be found in
/// `Beta1MigrationCoordinator.swift`.
class Beta1MigrationTests: XCTestCase {
    
    var mockBot: MockMigrationBot!
    var userDefaults: UserDefaults!
    var appConfig: AppConfiguration!
    let userDefaultsSuite = "com.Planetary.unit-tests.Beta1MigrationTests"
    var testPath: String!
    var appController: AppController!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testPath = NSTemporaryDirectory()
            .appending(UUID().uuidString)
            .appending("/PlanetaryUnitTests")
            .appending("/Beta1MigrationTests")
        MockMigrationBot.databaseDirectory = testPath
        try FileManager.default.createDirectory(atPath: testPath, withIntermediateDirectories: true)
        userDefaults = UserDefaults(suiteName: userDefaultsSuite)
        userDefaults.dictionaryRepresentation().keys.forEach { userDefaults.set(nil, forKey: $0) }
        mockBot = MockMigrationBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())
        appConfig = MockAppConfiguration(with: botTestsKey)
        appConfig.network = botTestNetwork
        appConfig.hmacKey = botTestHMAC
        appConfig.bot = mockBot
        appController = await AppController()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        userDefaults.removeSuite(named: userDefaultsSuite)

        mockBot.exit()
        do {
            try await mockBot.logout()
        } catch {
            guard case BotError.notLoggedIn = error else {
                throw error
            }
        }
    }
    
    // MARK: - Beta1MigrationCoordinator
    
    /// Verifies that the proper user defaults keys are set after the migration
    func testUserDefaultsSetAfterMigration() async throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        // Arrange
        // Sanity checks
        XCTAssertEqual(self.userDefaults.bool(forKey: "PerformedBeta1Migration"), false)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
        
        // Act
        _ = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Assert
        XCTAssertEqual(self.userDefaults.bool(forKey: "PerformedBeta1Migration"), true)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), "beta2Test")
    }
    
    /// Verifies that the proper user defaults keys are set when a user creates a new profile
    func testUserDefaultsSetAfterNewAccountCreation() async throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        // Act
        try await mockBot.login(config: appConfig)
        
        // Assert
        XCTAssertEqual(self.userDefaults.bool(forKey: "PerformedBeta1Migration"), false)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), "beta2Test")
    }
    
    func testMigrationDoesntRunTwiceForDifferentProfiles() async throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        // Arrange
        // swiftlint:disable line_length indentation_width
        let bobSecret = Secret(from: """
            {
              "curve": "ed25519",
              "public": "MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519",
              "private": "lnozk+qbbO86fv4SkclDqnRH4ilbStDjkr6ZZdVErAgyE6Qw/eMMKC5ttJWXlxWtmI8jdCh0I1eE6ew8DN1LAQ==.ed25519",
              "id": "@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519"
            }
            """)!
        let bobConfig = MockAppConfiguration(with: bobSecret)
        bobConfig.network = botTestNetwork
        bobConfig.hmacKey = botTestHMAC
        bobConfig.bot = mockBot
        
        let aliceSecret = Secret(from: """
            {
                "id":"@GfNGDgRATmajkZlZ2xw5v5AY+LUkimtmL1hzdoxcnsQ=.ed25519",
                "private":"jqlylNN9AykX3dtFyMsa5GDov4L/1i8qPwolGcM77NoZ80YOBEBOZqORmVnbHDm/kBj4tSSKa2YvWHN2jFyexA==.ed25519",
                "curve":"ed25519",
                "public":"GfNGDgRATmajkZlZ2xw5v5AY+LUkimtmL1hzdoxcnsQ=.ed25519"
            }
            """)!
        // swiftlint:enable line_length indentation_width
        let aliceConfig = MockAppConfiguration(with: aliceSecret)
        aliceConfig.network = botTestNetwork
        aliceConfig.hmacKey = botTestHMAC
        aliceConfig.bot = mockBot
        
        // Act
        // Migrate Bob
        var migrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: bobConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        XCTAssertEqual(migrating, true)
        XCTAssertEqual(mockBot.identity, bobSecret.identity)
        
        try await mockBot.logout()
        
        // Try to migrate alice
        migrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: aliceConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        XCTAssertEqual(migrating, false)
        XCTAssertEqual(mockBot.identity, nil)
    }

    /// Verifies that the user cannot publish after the migration has started if forked feed protection is enabled.
    func testForkedFeedProtectionAfterMigration() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        appConfig.numberOfPublishedMessages = 1
        
        // Act
        let migrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        XCTAssertEqual(migrating, true)
        XCTAssertEqual(mockBot.identity, appConfig.identity)
        do {
            _ = try await mockBot.publish(content: testPost)
            XCTFail("Expected publish to throw an error.")
        } catch {
            XCTAssertEqual(error.localizedDescription, BotError.forkProtection.localizedDescription)
        }
    }
    
    // MARK: - Launch View Controller
    
    /// Verifies that the LaunchViewController starts the migration for a user with an old go-ssb database.
    func testLaunchViewControllerTriggersMigration() async throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        // Arrange
        Onboarding.set(status: .completed, for: appConfig.identity!)
        let sut = await LaunchViewController(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = await sut.view
        
        // Assert
        let expectation = XCTBlockExpectation {
            self.userDefaults.bool(forKey: "PerformedBeta1Migration") == true &&
            self.userDefaults.string(forKey: "GoBotDatabaseVersion") == "beta2Test"
        }
        
        wait(for: [expectation], timeout: 10)
    }
        
    /// Verifies that the LaunchViewController doees not start the migration on a fresh install of the app, when there
    /// is no AppConfiguration in the keychain.
    func testLaunchViewControllerDoesNotTriggerMigrationOnFreshInstall() throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        // Arrange
        let mockData = try XCTUnwrap("mockDatabase".data(using: .utf8))
        let databaseURL = try XCTUnwrap(URL(fileURLWithPath: testPath.appending("/mockDatabase")))
        let sut = LaunchViewController(
            appConfiguration: nil,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        try mockData.write(to: databaseURL)
        _ = sut.view
        /// Wait for onboarding to be presented
        let expectation = XCTBlockExpectation {
            self.appController.children.first is OnboardingViewController
        }
        wait(for: [expectation], timeout: 10)
        
        // Assert
        XCTAssertEqual(userDefaults.bool(forKey: "PerformedBeta1Migration"), false)
        XCTAssertEqual(userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
        XCTAssertEqual(try Data(contentsOf: databaseURL), mockData)
    }
    
    /// Verifies that the LaunchViewController doees not start the migration on an AppConfiguration that has been
    /// created but hasn't started Onboarding yet.
    func testLaunchViewControllerDoesNotTriggerMigrationOnFreshAccount() throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        // Arrange
        Onboarding.set(status: .notStarted, for: appConfig.identity!)
        let mockData = try XCTUnwrap("mockDatabase".data(using: .utf8))
        let databaseURL = try XCTUnwrap(URL(fileURLWithPath: testPath.appending("/mockDatabase")))
        let sut = LaunchViewController(
            appConfiguration: nil,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        try mockData.write(to: databaseURL)
        _ = sut.view
        /// Wait for onboarding to be presented
        let expectation = XCTBlockExpectation {
            self.appController.children.first is OnboardingViewController
        }
        wait(for: [expectation], timeout: 10)
        
        // Assert
        XCTAssertEqual(userDefaults.bool(forKey: "PerformedBeta1Migration"), false)
        XCTAssertEqual(userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
        XCTAssertEqual(try Data(contentsOf: databaseURL), mockData)
    }
    
    /// Verifies that the LaunchViewController doees not start the migration on an AppConfiguration that has started
    /// onboarding but hasn't completed it yet.
    func testLaunchViewControllerDoesNotTriggerMigrationOnAccountRestore() throws {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("This test is expected to fail until #514 is implemented", options: options)
        
        Onboarding.set(status: .started, for: appConfig.identity!)
        let mockData = try XCTUnwrap("mockDatabase".data(using: .utf8))
        let databaseURL = try XCTUnwrap(URL(fileURLWithPath: testPath.appending("/mockDatabase")))
        let sut = LaunchViewController(
            appConfiguration: nil,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        try mockData.write(to: databaseURL)
        _ = sut.view
        /// Wait for onboarding to be presented
        let expectation = XCTBlockExpectation {
            self.appController.children.first is OnboardingViewController
        }
        wait(for: [expectation], timeout: 10)
        
        // Assert
        XCTAssertEqual(userDefaults.bool(forKey: "PerformedBeta1Migration"), false)
        XCTAssertEqual(userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
        XCTAssertEqual(try Data(contentsOf: databaseURL), mockData)
    }
}

class MockAppConfiguration: AppConfiguration {
    override func apply() {
        // no-op, don't mess with the keychain
    }
}

class MockMigrationBot: GoBot {
    
    static var databaseDirectory = NSTemporaryDirectory()
        .appending("/PlanetaryUnitTests")
        .appending("/Beta1MigrationTests")
    
    override var version: String {
        "beta2Test"
    }
    
    override class func databaseDirectory(for configuration: AppConfiguration) throws -> String {
        databaseDirectory
    }
}