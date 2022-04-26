//
//  GoBotIntegrationTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable force_unwrapping implicitly_unwrapped_optional

/// Warning: running these test will delete the database on whatever device they execute on.
class GoBotIntegrationTests: XCTestCase {
    
    /// The system under test
    var sut: GoBot!
    var workingDirectory: String!
    var userDefaults: UserDefaults!
    var appConfig: AppConfiguration!
    let fm = FileManager.default

    override func setUpWithError() throws {
        // We should refactor GoBot to use a configurable directory, so we don't clobber existing data every time we
        // run the unit tests. For now this will have to do.
        workingDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!
            .appending("/FBTT")

        // start fresh
        do { try fm.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }
        
        userDefaults = UserDefaults()
        
        sut = GoBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())
        
        appConfig = AppConfiguration(with: botTestsKey)
        appConfig.network = botTestNetwork
        appConfig.hmacKey = botTestHMAC
        appConfig.bot = sut
        
        let loginExpectation = self.expectation(description: "login")
        sut.login(config: appConfig) {
            error in
            defer { loginExpectation.fulfill() }
            XCTAssertNil(error)
        }
        self.wait(for: [loginExpectation], timeout: 10)

        let nicks = ["alice"]
        for n in nicks {
            try sut.testingCreateKeypair(nick: n)
        }
    }

    override func tearDown() async throws {
        try await super.tearDown()
        
        do {
            try await sut.logout()
        } catch {
            guard case BotError.notLoggedIn = error else {
                throw error
            }
        }
        sut.exit()
        do {
            try fm.removeItem(atPath: workingDirectory)
        } catch {
            print(error)
        }
    }

    /// Verifies that we can correctly refresh the `ViewDatabase` from the go-ssb log even after `publish` has copied
    /// some posts with a greater sequence number into `ViewDatabase` already.
    func testRefreshGivenPublish() throws {
        // Arrange
        for i in 0..<10 {
            _ = sut.testingPublish(as: "alice", content: Post(text: "Alice \(i)"))
        }
        
        // Act
        let postExpectation = self.expectation(description: "post published")
        let bobPost = Post(text: "Bob 0")
        sut.publish(content: bobPost, completionQueue: .main) { messageID, error in
            XCTAssertNotNil(messageID)
            XCTAssertNil(error)
            postExpectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
        
        let refreshExpectation = self.expectation(description: "refresh completed")
        sut.refresh(load: .long, queue: .main) { error, _, _ in
            XCTAssertNil(error)
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
        
        // Assert
        var statistics = BotStatistics()
        let statisticsExpectation = self.expectation(description: "statistics fetched")
        sut.statistics() { newStatistics in
            statistics = newStatistics
            statisticsExpectation.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(statistics.repo.messageCount, 11)
        XCTAssertEqual(statistics.repo.numberOfPublishedMessages, 1)
        XCTAssertEqual(try sut.database.messageCount(), 11)
    }
    
    func testRecentlyDownloadedPostCountGivenNoRecentlyDownloadedPosts() async throws {
        // Act
        let statistics = await sut.statistics()
        
        // Assert
        XCTAssertEqual(statistics.recentlyDownloadedPostCount, 0)
        XCTAssertEqual(statistics.recentlyDownloadedPostDuration, 15)
    }
    
    func testRecentlyDownloadedPostCountGivenTwoRecentlyDownloadedPosts() async throws {
        // Arrange
        for i in 0..<10 {
            _ = sut.testingPublish(as: "alice", content: Post(text: "Alice \(i)"))
        }
        try await sut.refresh(load: .long)
        
        // Act
        let statistics = await sut.statistics()

        // Assert
        XCTAssertEqual(statistics.recentlyDownloadedPostCount, 10)
        XCTAssertEqual(statistics.recentlyDownloadedPostDuration, 15)
    }
    
    func testDropDatabaseWhenLoggedIn() async throws {
        // Arrange
        let mockData = try XCTUnwrap("mockDatabase".data(using: .utf8))
        let databaseURL = try XCTUnwrap(
            URL(fileURLWithPath: GoBot.databaseDirectory(for: appConfig).appending("/mockDatabase"))
        )
        try mockData.write(to: databaseURL)

        // Act
        try await sut.dropDatabase(for: appConfig)

        // Assert
        XCTAssertThrowsError(try Data(contentsOf: databaseURL))
    }
    
    func testDropDatabaseWhenLoggedOut() async throws {
        // Arrange
        let mockData = try XCTUnwrap("mockDatabase".data(using: .utf8))
        let databaseURL = try XCTUnwrap(
            URL(fileURLWithPath: GoBot.databaseDirectory(for: appConfig).appending("/mockDatabase"))
        )
        try mockData.write(to: databaseURL)
        try await sut.logout()
        
        // Act
        try await sut.dropDatabase(for: appConfig)
        
        // Assert
        XCTAssertThrowsError(try Data(contentsOf: databaseURL))
    }
    
    func testLogoutWithDirectoryMissing() throws {
        // Arrange
        let firstLogout = self.expectation(description: "first logout finished")
        sut.logout(completion: { error in
            XCTAssertNil(error)
            firstLogout.fulfill()
        })
        
        waitForExpectations(timeout: 10)
        
        // Act
        do {
            try fm.removeItem(atPath: workingDirectory)
        } catch {
            print(error)
        }

        let secondLogout = self.expectation(description: "second logout finished")
        sut.logout(completion: { error in
            XCTAssertNotNil(error)
            secondLogout.fulfill()
        })
        
        waitForExpectations(timeout: 10)
    }
    
    @MainActor func testLogoutWithDirectoryPresent() throws {
        // Arrange
        let firstLogout = self.expectation(description: "first logout finished")
        sut.logout { error in
            XCTAssertNil(error)
            firstLogout.fulfill()
        }
        
        waitForExpectations(timeout: 10)
        
        // Act
        try fm.removeItem(atPath: workingDirectory)
        try fm.createDirectory(atPath: workingDirectory, withIntermediateDirectories: true)

        let secondLogout = self.expectation(description: "second logout finished")
        sut.logout { error in
            XCTAssertNotNil(error)
            secondLogout.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }
    
    @MainActor func testLogoutTwice() throws {
        let firstLogout = self.expectation(description: "first logout finished")
        sut.logout { error in
            XCTAssertNil(error)
            firstLogout.fulfill()
        }
        
        waitForExpectations(timeout: 10)
        
        let secondLogout = self.expectation(description: "second logout finished")
        sut.logout { error in
            XCTAssertNotNil(error)
            secondLogout.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }

    func testLoginLogoutLoop() {
        continueAfterFailure = false
        
        for i in 1...100 {
            var ex = self.expectation(description: "login \(i)")
            sut.login(config: appConfig) {
                error in
                XCTAssertNil(error)
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)

            ex = self.expectation(description: "logout \(i)")
            sut.exit()
            sut.logout() {
                error in
                XCTAssertNil(error)
                ex.fulfill()
            }
            self.wait(for: [ex], timeout: 10)
        }
    }

    // MARK: - Forked Feed Protection
    
    /// Verifies that the GoBot checks the `"prevent_feed_from_forks"` settings and avoids publishing when the number
    /// of published messages is higher than the number of messages in go-ssb.
    func testForkedFeedProtectionWhenEnabled() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        appConfig.numberOfPublishedMessages = 999
        userDefaults.set(true, forKey: "prevent_feed_from_forks")
        
        // Act
        do {
            let ref = try await sut.publish(content: testPost)
            
        // Assert
            XCTAssertNil(ref)
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    /// Verifies that the GoBot checks the `"prevent_feed_from_forks"` settings and disables fork protection when it
    /// is false
    func testForkedFeedProtectionWhenDisabled() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        AppConfiguration.current?.numberOfPublishedMessages = 999
        userDefaults.set(false, forKey: "prevent_feed_from_forks")
        
        // Act
        let ref = try await sut.publish(content: testPost)
        
        // Assert
        XCTAssertNotNil(ref)
    }
    
    /// Verifies that the GoBot assumes the `"prevent_feed_from_forks"` setting is `true` when it hasn't been set.
    func testForkedFeedProtectionWhenNotSet() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        appConfig.numberOfPublishedMessages = 999
        userDefaults.set(nil, forKey: "prevent_feed_from_forks")
        
        // Act
        do {
            let ref = try await sut.publish(content: testPost)
            
        // Assert
            XCTAssertNil(ref)
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    /// Verifies that the GoBot increments the published message count in the app config when publishing a message.
    func testPublishIncrementsPublishedMessageCount() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        AppConfiguration.current?.numberOfPublishedMessages = 0
        
        // Act
        let ref = try await sut.publish(content: testPost)
        
        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(ref)
    }
    
    /// Tests that forked feed protection updates correctly after a user imports a key and restores their feed.
    func testPublishSetsPublishMessageCountAfterRestore() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        AppConfiguration.current?.numberOfPublishedMessages = 0
        userDefaults.set(false, forKey: "prevent_feed_from_forks")
        let author = try XCTUnwrap(appConfig.identity)
        let nowFloat = Date().millisecondsSince1970
        let existingMessage = KeyValueFixtures.keyValue(
            timestamp: nowFloat,
            receivedTimestamp: nowFloat,
            receivedSeq: -1,
            author: author
        )
        
        // Act
        // Write a message without incrementing the numberOfPublishedMessages to simulate a user redownloading their
        // own feed after importing their secret key.
        try sut.database.fillMessages(msgs: [existingMessage])
        let ref = try await sut.publish(content: testPost)
        
        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 2)
        XCTAssertNotNil(ref)
    }

    /// Verifies that the GoBot can publish a message with an emoji
    func testPublishAnEmoji() async throws {
        // Arrange
        let testPost = Post(text: "🪲")
        AppConfiguration.current?.numberOfPublishedMessages = 0

        // Act
        let ref = try await sut.publish(content: testPost)

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(ref)
    }

    /// Verifies that the GoBOt can publish a message with a mention
    func testPublishWithAMention() async throws {
        // Arrange
        let mention = Mention(
            link: Identity("@j8jAl6Qs54VKIVQ5Jlja+Y3EQ/OCS6u85xGsNUGgb/g=.ed25519"),
            name: "Martin Dutra",
            metadata: nil
        )
        let testPost = Post(
            blobs: nil,
            branches: nil,
            hashtags: nil,
            mentions: [mention],
            root: nil,
            text: "Be yourself; everyone else is already taken"
        )
        AppConfiguration.current?.numberOfPublishedMessages = 0

        // Act
        let ref = try await sut.publish(content: testPost)

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(ref)
    }

    /// Verifies that the GoBot can publish a message with a mention whose name has an emoji
    func testPublishWithAMentionWithEmoji() async throws {
        // Arrange
        let mention = Mention(
            link: Identity("@j8jAl6Qs54VKIVQ5Jlja+Y3EQ/OCS6u85xGsNUGgb/g=.ed25519"),
            name: "Martin Dutra 🪲",
            metadata: nil
        )
        let testPost = Post(
            blobs: nil,
            branches: nil,
            hashtags: nil,
            mentions: [mention],
            root: nil,
            text: "Be yourself; everyone else is already taken"
        )
        AppConfiguration.current?.numberOfPublishedMessages = 0

        // Act
        let ref = try await sut.publish(content: testPost)

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(ref)
    }
    
    /// Verifies that the statitistics() function updates the number of published messages in the AppConfiguration.
    func testStatisticsFunctionSetsNumberOfPublishedMessages() async throws {
        // Arrange
        for _ in 0..<5 {
            let testPost = Post(text: "\(#function)")
            _ = try await sut.publish(content: testPost)
        }
        AppConfiguration.current?.numberOfPublishedMessages = 0
        
        // Act
        _ = await sut.statistics()
        
        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 5)
    }
    
    /// Verifies that reading the statitistics property updates the number of published messages in
    /// the AppConfiguration.
    func testStatisticsPropertySetsNumberOfPublishedMessages() async throws {
        // Arrange
        for _ in 0..<5 {
            let testPost = Post(text: "\(#function)")
            _ = try await sut.publish(content: testPost)
        }
        AppConfiguration.current?.numberOfPublishedMessages = 0
        
        // Act
        _ = sut.statistics
        
        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 5)
    }

    // MARK: - Preloaded Pubs
    
    func testPubsArePreloaded() async throws {
        // Arrange
        try await tearDown()
        do { try fm.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }

        let mockPreloader = MockPreloadedPubService()
        sut = GoBot(preloadedPubService: mockPreloader)
        let loginExpectation = self.expectation(description: "login")
        
        // Act
        sut.login(config: appConfig) { error in
            defer { loginExpectation.fulfill() }
            XCTAssertNil(error)
        }
        self.wait(for: [loginExpectation], timeout: 10)
        
        // Assert
        XCTAssertEqual(mockPreloader.preloadPubsCallCount, 1)
    }
}

class MockPreloadedPubService: PreloadedPubService {
    required init(blobService: PreloadedBlobsService.Type = PreloadedBlobsServiceAdapter.self) {}
    var preloadPubsCallCount = 0
    var preloadPubsBotParameter: Bot?
    func preloadPubs(in bot: Bot, from bundle: Bundle? = nil) {
        preloadPubsCallCount += 1
        preloadPubsBotParameter = bot
    }
}
