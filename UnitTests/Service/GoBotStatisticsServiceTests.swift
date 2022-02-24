//
//  GoBotStatisticsServiceTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import XCTest

class BotStatisticsServiceTests: XCTestCase {
    
    var sut: BotStatisticsServiceAdaptor!
    
    var mockBot: FakeBot!

    override func setUpWithError() throws {
        mockBot = FakeBot()
        sut = BotStatisticsServiceAdaptor(bot: mockBot, refreshInterval: 0.001)
        
    }

    func testSubscribingEmitsStatistics() async throws {
        // Arrange
        let firstStatistics = BotStatistics(
            lastSyncDate: Date(),
            lastSyncDuration: 1,
            lastRefreshDate: Date(),
            lastRefreshDuration: 1,
            repo: RepoStatistics(
                path: nil,
                feedCount: 1,
                messageCount: 1,
                numberOfPublishedMessages: 1,
                lastHash: "hash"
            ),
            peer: PeerStatistics(
                count: 1,
                connectionCount: 1,
                identities: [],
                open: []
            ),
            db: DatabaseStatistics(lastReceivedMessage: 1)
        )
        let secondStatistics = BotStatistics(
            lastSyncDate: Date(),
            lastSyncDuration: 2,
            lastRefreshDate: Date(),
            lastRefreshDuration: 2,
            repo: RepoStatistics(
                path: nil,
                feedCount: 2,
                messageCount: 2,
                numberOfPublishedMessages: 2,
                lastHash: "hash"
            ),
            peer: PeerStatistics(
                count: 2,
                connectionCount: 2,
                identities: [],
                open: []
            ),
            db: DatabaseStatistics(lastReceivedMessage: 2)
        )
        mockBot.mockStatistics = [secondStatistics, firstStatistics, BotStatistics()]
        
        // Act
        let statisticsPublisher = await sut.subscribe().collectNext(2)
        let nextTwoStatistics = try await publisherCompletion(statisticsPublisher).result.get()

        // Assert
        XCTAssertEqual(nextTwoStatistics.first, firstStatistics)
        XCTAssertEqual(nextTwoStatistics.last, secondStatistics)
        XCTAssertEqual(nextTwoStatistics.count, 2)
    }
}
