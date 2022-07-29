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
    let fileManager = FileManager.default

    override func setUpWithError() throws {
        // We should refactor GoBot to use a configurable directory, so we don't clobber existing data every time we
        // run the unit tests. For now this will have to do.
        workingDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!
            .appending("/FBTT")

        // start fresh
        do { try fileManager.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }
        
        userDefaults = UserDefaults()
        
        sut = GoBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())
        
        appConfig = AppConfiguration(with: botTestsKey)
        appConfig.network = botTestNetwork
        appConfig.hmacKey = botTestHMAC
        appConfig.bot = sut
        
        let loginExpectation = self.expectation(description: "login")
        sut.login(config: appConfig) { error in
            defer { loginExpectation.fulfill() }
            XCTAssertNil(error)
        }
        self.wait(for: [loginExpectation], timeout: 10)

        let nicks = ["alice", "bob"]
        for nick in nicks {
            try sut.testingCreateKeypair(nick: nick)
        }
        try super.setUpWithError()
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
        await sut.exit()
        do {
            try fileManager.removeItem(atPath: workingDirectory)
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
        sut.refresh(load: .long, queue: .main) { result, _ in
            XCTAssertNotNil(try? result.get())
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
        
        // Assert
        var statistics = BotStatistics()
        let statisticsExpectation = self.expectation(description: "statistics fetched")
        sut.statistics { newStatistics in
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
            URL(fileURLWithPath: appConfig.databaseDirectory().appending("/mockDatabase"))
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
            URL(fileURLWithPath: appConfig.databaseDirectory().appending("/mockDatabase"))
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
            try fileManager.removeItem(atPath: workingDirectory)
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
        try fileManager.removeItem(atPath: workingDirectory)
        try fileManager.createDirectory(atPath: workingDirectory, withIntermediateDirectories: true)

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

    func testLoginLogoutLoop() async throws {
        try await sut.login(config: appConfig)

        await sut.exit()
        try await sut.logout()
        
        try await sut.login(config: appConfig)
    }

    // MARK: - Publishing
    
    /// Verifies that the GoBot checks the `"prevent_feed_from_forks"` settings and avoids publishing when the number
    /// of published messages is higher than the number of messages in go-ssb.
    func testForkedFeedProtectionWhenEnabled() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        appConfig.numberOfPublishedMessages = 999
        userDefaults.set(true, forKey: "prevent_feed_from_forks")
        
        // Act
        do {
            let messageRef = try await sut.publish(content: testPost)
            
        // Assert
            XCTAssertNil(messageRef)
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
        let messageRef = try await sut.publish(content: testPost)
        
        // Assert
        XCTAssertNotNil(messageRef)
    }
    
    /// Verifies that the GoBot assumes the `"prevent_feed_from_forks"` setting is `true` when it hasn't been set.
    func testForkedFeedProtectionWhenNotSet() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        appConfig.numberOfPublishedMessages = 999
        userDefaults.set(nil, forKey: "prevent_feed_from_forks")
        
        // Act
        do {
            let messageRef = try await sut.publish(content: testPost)
            
        // Assert
            XCTAssertNil(messageRef)
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
        let messageRef = try await sut.publish(content: testPost)
        
        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(messageRef)
    }
    
    /// Tests that forked feed protection updates correctly after a user imports a key and restores their feed.
    func testPublishSetsPublishMessageCountAfterRestore() async throws {
        // Arrange
        let testPost = Post(text: "\(#function)")
        AppConfiguration.current?.numberOfPublishedMessages = 0
        userDefaults.set(false, forKey: "prevent_feed_from_forks")
        let author = try XCTUnwrap(appConfig.identity)
        let nowFloat = Date().millisecondsSince1970
        let existingMessage = KeyValueFixtures.post(
            timestamp: nowFloat,
            receivedTimestamp: nowFloat,
            receivedSeq: -1,
            author: author
        )
        
        // Act
        // Write a message without incrementing the numberOfPublishedMessages to simulate a user redownloading their
        // own feed after importing their secret key.
        try sut.database.fillMessages(msgs: [existingMessage])
        let messageRef = try await sut.publish(content: testPost)
        
        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 2)
        XCTAssertNotNil(messageRef)
    }

    /// Verifies that the GoBot can publish a message with an emoji
    func testPublishAnEmoji() async throws {
        // Arrange
        let testPost = Post(text: "🪲")
        AppConfiguration.current?.numberOfPublishedMessages = 0

        // Act
        let messageRef = try await sut.publish(content: testPost)

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(messageRef)
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
        let messageRef = try await sut.publish(content: testPost)

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(messageRef)
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
        let messageRef = try await sut.publish(content: testPost)

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 1)
        XCTAssertNotNil(messageRef)
    }
    
    /// Tests that publishing from multiple threads simultaneously is safe. (It wasn't in #489)
    func testPublishSimultaneously() async throws {
        // Arrange
        let testPost = Post(text: "Be yourself; everyone else is already taken")
        appConfig.numberOfPublishedMessages = 0
        XCTAssertEqual(self.appConfig.numberOfPublishedMessages, 0)

        // Act
        await withThrowingTaskGroup(of: Void.self, body: { group in
            for _ in 0..<100 {
                group.addTask {
                    let messageID = try await self.sut.publish(testPost)
                    XCTAssertNotNil(messageID)
                    XCTAssert(self.appConfig.numberOfPublishedMessages <= 100)
                }
            }
        })

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 100)
    }
    
    /// Verifies that the GoBot can handle publishes from many tasks simultaneously, while the statistics function is
    /// also being called. Both of these can update the numberOfPublishedMessages in the AppConfig, and we had a
    /// race condition where this could fail in the past (#489).
    func testPublishSimultaneouslyWithStatistics() async throws {
        // Arrange
        let testPost = Post(text: "Be yourself; everyone else is already taken")
        appConfig.numberOfPublishedMessages = 0

        // Act
        await withThrowingTaskGroup(of: Void.self, body: { group in
            for _ in 0..<100 {
                group.addTask {
                    async let futureStats1 = self.sut.statistics()
                    async let futurePublishedID = try self.sut.publish(testPost)
                    async let futureStats2 = self.sut.statistics()
                    let stats1 = await futureStats1
                    let stats2 = await futureStats2
                    let publishedID = try await futurePublishedID
                    XCTAssert(stats1.repo.numberOfPublishedMessages <= 100)
                    XCTAssert(stats2.repo.numberOfPublishedMessages <= 100)
                    XCTAssertNotNil(publishedID)
                    XCTAssert(self.appConfig.numberOfPublishedMessages <= 100)
                }
            }
        })

        // Assert
        XCTAssertEqual(appConfig.numberOfPublishedMessages, 100)
    }
    
    /// Tests the performance of the publish function.
    func testPublishPerformance() throws {
        // Arrange
        let testPost = Post(text: "Be yourself; everyone else is already taken")
        appConfig.numberOfPublishedMessages = 0

        // Act
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            let expectation = self.expectation(description: "posted")
            startMeasuring()
            sut.publish(testPost) { messageID, error in
                XCTAssertNil(error)
                XCTAssertNotNil(messageID)
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1)
            stopMeasuring()
        }
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
    
    /// Verifies that the isRestoring value defaults to false.
    func testIsRestoringDefaultValue() {
        XCTAssertEqual(sut.isRestoring, false)
    }

    // MARK: - Preloaded Pubs
    
    func testPubsArePreloaded() async throws {
        // Arrange
        try await tearDown()
        do { try fileManager.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }

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

    // MARK: Hashtags

    func testOnePostWithThreeHashtag() async throws {
        let post = Post(attributedText: NSAttributedString(string: "Hello #one #two #three"))
        _ = sut.testingPublish(as: "alice", content: post)

        try await sut.refresh(load: .short)

        let keypairs = try sut.testingGetNamedKeypairs()
        let identity = try XCTUnwrap(keypairs["alice"])

        let hashtags = try await sut.hashtags(usedBy: identity, limit: 10)
        XCTAssertEqual(hashtags.count, 3)
    }

    func testThreePostsWithOneHashtagEach() async throws {
        let firstPost = Post(attributedText: NSAttributedString(string: "Hello #one"))
        _ = sut.testingPublish(as: "alice", content: firstPost)

        let secondPost = Post(attributedText: NSAttributedString(string: "Hello #two"))
        _ = sut.testingPublish(as: "alice", content: secondPost)

        let thirdPost = Post(attributedText: NSAttributedString(string: "Hello #three"))
        _ = sut.testingPublish(as: "alice", content: thirdPost)

        try await sut.refresh(load: .short)

        let keypairs = try sut.testingGetNamedKeypairs()
        let identity = try XCTUnwrap(keypairs["alice"])

        let hashtags = try await sut.hashtags(usedBy: identity, limit: 10)
        XCTAssertEqual(hashtags.count, 3)
    }

    func testLimitInHashtags() async throws {
        let post = Post(attributedText: NSAttributedString(string: "Hello #one #two #three"))
        _ = sut.testingPublish(as: "alice", content: post)

        try await sut.refresh(load: .short)

        let keypairs = try sut.testingGetNamedKeypairs()
        let identity = try XCTUnwrap(keypairs["alice"])

        let hashtags = try await sut.hashtags(usedBy: identity, limit: 2)
        XCTAssertEqual(hashtags.count, 2)
    }

    // MARK: Number of followers

    func testNumberOfFollowers() async throws {
        // Follow alice
        _ = sut.testingFollow(nick: "alice")

        // Alice follows Bob
        _ = sut.testingFollow(as: "alice", nick: "bob")

        try await sut.refresh(load: .short)

        let keypairs = try sut.testingGetNamedKeypairs()
        let aliceIdentity = try XCTUnwrap(keypairs["alice"])
        let bobIdentity = try XCTUnwrap(keypairs["bob"])

        let myFollowStats = try await sut.socialStats(for: botTestsKey.identity)
        XCTAssertEqual(myFollowStats.numberOfFollows, 1)
        XCTAssertEqual(myFollowStats.numberOfFollowers, 0)

        let aliceFollowStats = try await sut.socialStats(for: aliceIdentity)
        XCTAssertEqual(aliceFollowStats.numberOfFollows, 1)
        XCTAssertEqual(aliceFollowStats.numberOfFollowers, 1)

        let bobFollowStats = try await sut.socialStats(for: bobIdentity)
        XCTAssertEqual(bobFollowStats.numberOfFollows, 0)
        XCTAssertEqual(bobFollowStats.numberOfFollowers, 1)
    }

    // MARK: Home feed

    func testWith10Posts() async throws {
        // I publish 10 messages
        for i in 0..<10 {
            _ = try await sut.publish(content: Post(text: "Me \(i)"))
        }

        try await sut.refresh(load: .short)

        // Home feed should have my 10 messages
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 10)
    }

    func testFollowingOnePerson() async throws {
        let keypairs = try sut.testingGetNamedKeypairs()
        let alice = try XCTUnwrap(keypairs["alice"])

        // Follow alice
        _ = sut.testingFollow(nick: "alice")
        _ = sut.testingPublish(as: "alice", content: About(about: alice, name: "Alice"))

        try await sut.refresh(load: .short)

        // Home feed should have my follow
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 1)
    }

    func testFollowingOnePersonWithoutAbout() async throws {
        // Follow alice
        _ = sut.testingFollow(nick: "alice")

        try await sut.refresh(load: .short)

        // Home feed should have my follow
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 0)
    }

    func testUnknownPersonWith10Posts() async throws {
        // Alice publishes 10 posts
        for i in 0..<10 {
            _ = sut.testingPublish(as: "alice", content: Post(text: "Alice \(i)"))
        }

        try await sut.refresh(load: .short)

        // Home feed should not have messages (I am not following Alice)
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 0)
    }

    func testPersonAtOneHopWith10Posts() async throws {
        let keypairs = try sut.testingGetNamedKeypairs()
        let alice = try XCTUnwrap(keypairs["alice"])

        // Follow alice
        _ = sut.testingFollow(nick: "alice")
        _ = sut.testingPublish(as: "alice", content: About(about: alice, name: "Alice"))

        // Alice publishes 10 posts
        for i in 0..<10 {
            _ = sut.testingPublish(as: "alice", content: Post(text: "Alice \(i)"))
        }

        try await sut.refresh(load: .short)

        // Home feed should have 10 alice posts and 1 follow message
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 11)
    }

    func testPersonAtTwoHopsWith10Posts() async throws {
        let keypairs = try sut.testingGetNamedKeypairs()
        let aliceIdentity = try XCTUnwrap(keypairs["alice"])
        let bobIdentity = try XCTUnwrap(keypairs["bob"])

        // Follow alice
        _ = sut.testingFollow(nick: "alice")
        _ = sut.testingPublish(as: "alice", content: About(about: aliceIdentity, name: "Alice"))

        // Alice follows Bob
        _ = sut.testingFollow(as: "alice", nick: "bob")
        _ = sut.testingPublish(as: "bob", content: About(about: bobIdentity, name: "Bob"))

        // Bob publishes 10 posts
        for i in 0..<10 {
            _ = sut.testingPublish(as: "bob", content: Post(text: "Bob \(i)"))
        }

        try await sut.refresh(load: .short)

        // Home feed should have my follow and Alice's follow
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 2)
    }

    func testPersonAtOneHopFollowsAnotherAtTwoHops() async throws {
        let keypairs = try sut.testingGetNamedKeypairs()
        let aliceIdentity = try XCTUnwrap(keypairs["alice"])
        let bobIdentity = try XCTUnwrap(keypairs["bob"])

        // Follow alice
        _ = sut.testingFollow(nick: "alice")
        _ = sut.testingPublish(as: "alice", content: About(about: aliceIdentity, name: "Alice"))

        // Alice follows Bob
        _ = sut.testingFollow(as: "alice", nick: "bob")
        _ = sut.testingPublish(as: "bob", content: About(about: bobIdentity, name: "Bob"))

        try await sut.refresh(load: .short)

        // Home feed should have Alice follow message
        let proxy = try await sut.recent()
        XCTAssertEqual(proxy.count, 2)
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
