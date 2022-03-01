//
//  ConnectedPeersViewCoordinatorTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest
import Combine

actor MockBotStatisticsService: BotStatisticsService {
        
    var statisticsPasthrough: PassthroughSubject<BotStatistics, Never>

    init(refreshInterval: DispatchTimeInterval = .seconds(1)) {
        statisticsPasthrough = PassthroughSubject<BotStatistics, Never>()
    }
    
    func subscribe() async -> AnyPublisher<BotStatistics, Never> {
        return statisticsPasthrough.print().eraseToAnyPublisher()
    }
}


class ConnectedPeersViewCoordinatorTests: XCTestCase {
    
    /// The system under test
    var sut: ConnectedPeersViewCoordinator!
    
    var mockStatistics: MockBotStatisticsService!
    
    var mockBot: FakeBot!

    override func setUpWithError() throws {
        mockBot = FakeBot()
        mockStatistics = MockBotStatisticsService()
        sut = ConnectedPeersViewCoordinator(bot: mockBot, statisticsService: mockStatistics)
    }

    func testPublishingNewStatisticsUpdatesPeers() async throws {
        // Arrange
        XCTAssertEqual(sut.peers, [])
        let newStatistics = BotStatistics(
            lastSyncDate: Date(),
            lastSyncDuration: 1,
            lastRefreshDate: Date(),
            lastRefreshDuration: 2,
            repo: RepoStatistics(
                path: nil,
                feedCount: 3,
                messageCount: 4,
                numberOfPublishedMessages: 5,
                lastHash: "hash"
            ),
            peer: PeerStatistics(
                count: 3,
                connectionCount: 2,
                identities: [],
                open: [
                    ("1.1.1.1", IdentityFixture.alice.id),
                    ("2.2.2.2", IdentityFixture.noAbout.id),
                    ("3.3.3.3", IdentityFixture.noName.id),
                ]
            ),
            db: DatabaseStatistics(lastReceivedMessage: 10)
        )
        let expectedPeers = [
            PeerConnectionInfo(
                id: IdentityFixture.alice.id,
                name: "Alice",
                imageMetadata: nil,
                currentlyActive: true
            ),
            PeerConnectionInfo(
                id: IdentityFixture.noAbout.id,
                name: IdentityFixture.noAbout.id,
                imageMetadata: nil,
                currentlyActive: true
            ),
            PeerConnectionInfo(
                id: IdentityFixture.noName.id,
                name: IdentityFixture.noName,
                imageMetadata: nil,
                currentlyActive: true
            )
        ]
        
        let publisherCompletion = await makeAwaitable(publisher: sut.$peers.collectNext())

        // Act
        await mockStatistics.statisticsPasthrough.send(newStatistics)
        let publishedPeers = try await publisherCompletion.result.get()
        
        // Assert
        XCTAssertEqual(publishedPeers.first, expectedPeers)
    }
    
    /// Verifies that the coordinator publishes the latest recentPostCount from its BotStatisticsService
    func testRecentlyDownloadedPostCount() async throws {
        // Arrange
        let newStatistics = BotStatistics(
            lastSyncDate: Date(),
            lastSyncDuration: 1,
            lastRefreshDate: Date(),
            lastRefreshDuration: 2,
            recentlyDownloadedPostCount: 888,
            recentlyDownloadedPostDuration: 999,
            repo: RepoStatistics(
                path: nil,
                feedCount: 3,
                messageCount: 4,
                numberOfPublishedMessages: 5,
                lastHash: "hash"
            ),
            peer: PeerStatistics(
                count: 3,
                connectionCount: 2,
                identities: [],
                open: []
            ),
            db: DatabaseStatistics(lastReceivedMessage: 10)
        )
        
        let recentlyDownloadedPostCountPublisher = await makeAwaitable(
            publisher: sut.$recentlyDownloadedPostCount.collectNext()
        )
        
        // Act
        await mockStatistics.statisticsPasthrough.send(newStatistics)
        let recentlyDownloadedPostCounts = try await recentlyDownloadedPostCountPublisher.result.get().first
        
        // Assert
        XCTAssertEqual(recentlyDownloadedPostCounts, 888)
    }
    
    /// Verifies that the coordinators passes through the recentlyDownloadedPostDuration from
    /// its `BotStatisticsService`.
    func testRecentlyDownloadedPostDuration() async throws {
        // Arrange
        let newStatistics = BotStatistics(
            lastSyncDate: Date(),
            lastSyncDuration: 1,
            lastRefreshDate: Date(),
            lastRefreshDuration: 2,
            recentlyDownloadedPostCount: 888,
            recentlyDownloadedPostDuration: 999,
            repo: RepoStatistics(
                path: nil,
                feedCount: 3,
                messageCount: 4,
                numberOfPublishedMessages: 5,
                lastHash: "hash"
            ),
            peer: PeerStatistics(
                count: 3,
                connectionCount: 2,
                identities: [],
                open: []
            ),
            db: DatabaseStatistics(lastReceivedMessage: 10)
        )
        
        let recentlyDownloadedPostDurationPublisher = await makeAwaitable(
            publisher: sut.$recentlyDownloadedPostDuration.collectNext()
        )
        
        // Act
        await mockStatistics.statisticsPasthrough.send(newStatistics)
        let recentlyDownloadedPostDuration = try await recentlyDownloadedPostDurationPublisher.result.get().first
        
        // Assert
        XCTAssertEqual(recentlyDownloadedPostDuration, "999 mins")
    }
}
