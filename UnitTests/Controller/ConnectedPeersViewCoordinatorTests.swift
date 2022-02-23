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
        
    var statisticsPasthrough: PassthroughSubject<BotStatistics?, Never>
    
    func subscribe() async -> AnyPublisher<BotStatistics?, Never> {
        return statisticsPasthrough.print().eraseToAnyPublisher()
    }

    init(refreshInterval: DispatchTimeInterval = .seconds(1)) {
        statisticsPasthrough = PassthroughSubject<BotStatistics?, Never>()
    }
}


class ConnectedPeersViewCoordinatorTests: XCTestCase {
    
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
                    ("Alice", IdentityFixture.alice),
                    ("Bob", IdentityFixture.bob)
                ]
            ),
            db: DatabaseStatistics(lastReceivedMessage: 10)
        )
        let expectedPeers = [
            PeerConnectionInfo(
                id: IdentityFixture.alice,
                name: "Alice",
                imageID: nil,
                currentlyActive: true
            ),
            PeerConnectionInfo(
                id: IdentityFixture.bob,
                name: "Bob",
                imageID: nil,
                currentlyActive: true
            )
        ]
        
        let publisherCompletion = await publisherCompletion(sut.$peers.collectNext())

        // Act
        await mockStatistics.statisticsPasthrough.send(newStatistics)
        
        // Assert
        let publishedPeers = try await publisherCompletion.result.get()
        XCTAssertEqual(publishedPeers.first, expectedPeers)
    }
}
