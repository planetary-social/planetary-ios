//
//  Beta1MigrationTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 4/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest
import SwiftUI

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping

/// Tests for the "beta1" go-ssb migration. More info on this migration can be found in
/// `Beta1MigrationCoordinator.swift`.
class Beta1MigrationTests: XCTestCase {
    
    var mockBot: MockMigrationBot!
    var userDefaults: UserDefaults!
    var appConfig: MockAppConfiguration!
    let userDefaultsSuite = "com.Planetary.unit-tests.Beta1MigrationTests"
    var testPath: String!
    var appController: MockAppController!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testPath = NSTemporaryDirectory()
            .appending(UUID().uuidString)
            .appending("/PlanetaryUnitTests")
            .appending("/Beta1MigrationTests")
        
        userDefaults = UserDefaults(suiteName: userDefaultsSuite)
        userDefaults.dictionaryRepresentation().keys.forEach { userDefaults.set(nil, forKey: $0) }
        mockBot = MockMigrationBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())
        appConfig = MockAppConfiguration(with: botTestsKey)
        appConfig.mockDatabaseDirectory = testPath
        appConfig.network = botTestNetwork
        appConfig.hmacKey = botTestHMAC
        appConfig.bot = mockBot
        appController = await MockAppController()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        userDefaults.removeSuite(named: userDefaultsSuite)

        await mockBot.exit()
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
        // Arrange
        try touchSQLiteDatabase()
        // Sanity checks
        XCTAssertEqual(self.userDefaults.bool(forKey: "StartedBeta1Migration"), false)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
        
        // Act
        _ = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Assert
        XCTAssertEqual(self.userDefaults.bool(forKey: "StartedBeta1Migration"), true)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), "beta2Test")
    }
    
    /// Verifies that the proper user defaults keys are set when a user creates a new profile
    func testUserDefaultsSetAfterNewAccountCreation() async throws {
        // Act
        try await mockBot.login(config: appConfig)
        
        // Assert
        XCTAssertEqual(self.userDefaults.bool(forKey: "StartedBeta1Migration"), false)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), "beta2Test")
    }
    
    /// Verifies that the migration won't run if we increment the version number in the future
    func testMigrationDoesntRunOnNewerVersion() async throws {
        // Arrange
        try touchSQLiteDatabase()
        self.userDefaults.set(false, forKey: "StartedBeta1Migration")
        self.userDefaults.set("beta3Test", forKey: "GoBotDatabaseVersion")
        
        // Act
        let isMigrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Assert
        XCTAssertEqual(isMigrating, false)
        XCTAssertEqual(self.userDefaults.bool(forKey: "StartedBeta1Migration"), false)
        XCTAssertEqual(self.userDefaults.string(forKey: "GoBotDatabaseVersion"), "beta3Test")
    }
    
    func testMigrationDoesntRunTwiceForDifferentProfiles() async throws {
        // Arrange
        // swiftlint:disable line_length indentation_width
        try touchSQLiteDatabase()
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
        bobConfig.mockDatabaseDirectory = testPath
        
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
        aliceConfig.mockDatabaseDirectory = testPath
        
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
        userDefaults.set(true, forKey: "CompletedBeta1Migration")
        userDefaults.synchronize()
        
        // Try to migrate alice
        migrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: aliceConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        XCTAssertEqual(migrating, false)
        XCTAssertEqual(mockBot.identity, nil)
    }
    
    /// Verifies that the LaunchViewController does not resume the migration after it has been completed
    func testLaunchViewControllerDoesNotResumeCompletedMigration() async throws {
        // Arrange
        try touchSQLiteDatabase()
        userDefaults.set(true, forKey: "CompletedBeta1Migration")
        userDefaults.set("beta2Test", forKey: "GoBotDatabaseVersion")
        
        // Act
        let isMigrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Assert
        XCTAssertEqual(isMigrating, false)
    }
        

    /// Verifies that the user cannot publish after the migration has started if forked feed protection is enabled.
    func testForkedFeedProtectionAfterMigration() async throws {
        // Arrange
        try touchSQLiteDatabase()
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
    
    // MARK: Bot isRestoring
    
    /// Verifies that the migration coordinator puts the bot into restoring mode.
    func testBotIsRestoringDuringMigration() async throws {
        // Arrange
        try touchSQLiteDatabase()
        XCTAssertEqual(mockBot.isRestoring, false)
        
        // Act
        let migrating = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        XCTAssertEqual(migrating, true)
        XCTAssertEqual(mockBot.isRestoring, true)
    }
    
    /// Verifies that the migration coordinator removes the bot from restoring mode when dismissed.
    @MainActor func testBotIsNotRestoringAfterMigration() async throws {
        // Arrange
        try touchSQLiteDatabase()
        XCTAssertEqual(mockBot.isRestoring, false)
        
        // Act
        // Present migration screen
        _ = try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        let hostingController = try XCTUnwrap(
            self.appController.presentedViewControllerParam as?
                UIHostingController<Beta1MigrationView<Beta1MigrationCoordinator>>
        )
        let migrationCoordinator = hostingController.rootView.viewModel
        
        // Dismiss migration screen
        migrationCoordinator.buttonPressed()
        
        XCTAssertEqual(mockBot.isRestoring, false)
    }
    
    // MARK: - Launch View Controller
    
    /// Verifies that the LaunchViewController starts the migration for a user with an old go-ssb database.
    func testLaunchViewControllerTriggersMigration() async throws {
        // Arrange
        Onboarding.set(status: .completed, for: appConfig.identity)
        try touchSQLiteDatabase()
        let sut = await LaunchViewController(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = await sut.view
        
        // Assert
        let expectation = XCTBlockExpectation {
            self.userDefaults.bool(forKey: "StartedBeta1Migration") == true &&
            self.userDefaults.string(forKey: "GoBotDatabaseVersion") == "beta2Test"
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    /// Verifies that the LaunchViewController resumes the migration if it was interrupted.
    /// than 20.
    func testLaunchViewControllerResumesMigration() throws {
        // Arrange
        try touchSQLiteDatabase()
        userDefaults.set(100, forKey: "Beta1MigrationResyncTarget")
        userDefaults.set(true, forKey: "StartedBeta1Migration")
        userDefaults.set("beta2Test", forKey: "GoBotDatabaseVersion")
        Onboarding.set(status: .completed, for: appConfig.identity)
        let sut = LaunchViewController(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = sut.view
        
        // Assert
        /// Wait for migration view to be presented
        let expectation = XCTBlockExpectation {
            self.appController.presentedViewControllerParam is
                UIHostingController<Beta1MigrationView<Beta1MigrationCoordinator>>
        }
        wait(for: [expectation], timeout: 10)
    }

    /// Verifies that the LaunchViewController starts the migration for a user with a SQLite database version older
    /// than 20.
    func testLaunchViewControllerTriggersMigrationForOldSQLite() async throws {
        // Arrange
        try touchSQLiteDatabase(version: 1)
        Onboarding.set(status: .completed, for: appConfig.identity)
        let sut = await LaunchViewController(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = await sut.view
        
        // Assert
        let expectation = XCTBlockExpectation {
            self.userDefaults.bool(forKey: "StartedBeta1Migration") == true &&
            self.userDefaults.string(forKey: "GoBotDatabaseVersion") == "beta2Test"
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    /// Verifies that the LaunchViewController doees not start the migration on a fresh install of the app, when there
    /// is no AppConfiguration in the keychain.
    func testLaunchViewControllerDoesNotTriggerMigrationOnFreshInstall() throws {
        // Arrange
        let sut = LaunchViewController(
            appConfiguration: nil,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = sut.view
        /// Wait for onboarding to be presented
        let expectation = XCTBlockExpectation {
            self.appController.children.first is OnboardingViewController
        }
        wait(for: [expectation], timeout: 10)
        
        // Assert
        XCTAssertEqual(userDefaults.bool(forKey: "StartedBeta1Migration"), false)
        XCTAssertEqual(userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
    }
    
    /// Verifies that the LaunchViewController doees not start the migration on an AppConfiguration that has been
    /// created but hasn't started Onboarding yet.
    func testLaunchViewControllerDoesNotTriggerMigrationOnFreshAccount() throws {
        // Arrange
        try touchSQLiteDatabase()
        Onboarding.set(status: .notStarted, for: appConfig.identity)
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
        XCTAssertEqual(userDefaults.bool(forKey: "StartedBeta1Migration"), false)
        XCTAssertEqual(userDefaults.string(forKey: "GoBotDatabaseVersion"), nil)
        XCTAssertEqual(try Data(contentsOf: databaseURL), mockData)
    }
    
    /// Verifies that the LaunchViewController does not start the migration on an AppConfiguration that has started
    /// onboarding but hasn't completed it yet.
    func testLaunchViewControllerDoesNotTriggerMigrationOnAccountRestore() throws {
        Onboarding.set(status: .completed, for: appConfig.identity)
        let sut = LaunchViewController(
            appConfiguration: appConfig,
            appController: appController,
            userDefaults: userDefaults
        )
        
        // Act
        _ = sut.view
        /// Wait for onboarding to be presented
        let expectation = XCTBlockExpectation {
            self.appController.children.first is MainViewController &&
            self.appController.presentedViewControllerParam == nil
        }
        wait(for: [expectation], timeout: 10)
        
        // Assert
        XCTAssertEqual(userDefaults.bool(forKey: "CompletedBeta1Migration"), false)
        XCTAssertEqual(userDefaults.string(forKey: "GoBotDatabaseVersion"), "beta2Test")
    }
    
    private func touchSQLiteDatabase(version: Int = 20) throws {
        try FileManager.default.createDirectory(atPath: testPath, withIntermediateDirectories: true)
        let mockData = try XCTUnwrap("mockDatabase".data(using: .utf8))
        let databaseURL = try XCTUnwrap(URL(fileURLWithPath: testPath.appending("/schema-built\(version).sqlite")))
        try mockData.write(to: databaseURL)
    }
}

class MockAppConfiguration: AppConfiguration {
    
    var mockDatabaseDirectory: String!
    
    override func apply() {
        // no-op, don't mess with the keychain
    }
    
    override func databaseDirectory() throws -> String {
        return mockDatabaseDirectory
    }
}

class MockMigrationBot: GoBot {
    override var version: String {
        "beta2Test"
    }
}

class MockAppController: AppController {
    
    var presentedViewControllerParam: UIViewController?
    
    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentedViewControllerParam = viewControllerToPresent
    }
}
