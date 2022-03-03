//
//  ConnectedPeersViewCoordinatorTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest
import Combine

actor BotStatisticsServiceMock: BotStatisticsService {
        
    var statisticsPasthrough: PassthroughSubject<BotStatistics, Never>

    init(refreshInterval: DispatchTimeInterval = .seconds(1)) {
        statisticsPasthrough = PassthroughSubject<BotStatistics, Never>()
    }
    
    func subscribe() async -> AnyPublisher<BotStatistics, Never> {
        return statisticsPasthrough.print().eraseToAnyPublisher()
    }
}

class ConnectedPeerListRouterMock: ConnectedPeerListRouter {
    
    var showProfileCallCount = 0
    var showProfileIdentityParameter: Identity?
    
    func showProfile(for identity: Identity) {
        showProfileCallCount += 1
        showProfileIdentityParameter = identity
    }
    
    var alertCallCount = 0
    var alertErrorParameter: Error?
    
    func alert(error: Error) {
        alertCallCount += 1
        alertErrorParameter = error
    }
}

class ConnectedPeerListCoordinatorTests: XCTestCase {
    
    /// The system under test
    var sut: ConnectedPeerListCoordinator!
    
    var mockStatistics: BotStatisticsServiceMock!
    
    var mockBot: FakeBot!
    
    var mockRouter: ConnectedPeerListRouterMock!
    
    let baseStatistics = BotStatistics(
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
            open: []
        ),
        db: DatabaseStatistics(lastReceivedMessage: 10)
    )
    
    let alicePeerConnectionInfo = PeerConnectionInfo(
        id: IdentityFixture.alice.id,
        identity: IdentityFixture.alice,
        name: "Alice",
        imageMetadata: nil,
        currentlyActive: true
    )
    
    let noAboutPeerConnectionInfo = PeerConnectionInfo(
        id: IdentityFixture.noAbout.id,
        identity: nil,
        name: IdentityFixture.noAbout.id,
        imageMetadata: nil,
        currentlyActive: true
    )
    
    let noNamePeerConnectionInfo = PeerConnectionInfo(
        id: IdentityFixture.noName.id,
        identity: IdentityFixture.noName,
        name: IdentityFixture.noName.id,
        imageMetadata: nil,
        currentlyActive: true
    )

    override func setUpWithError() throws {
        mockBot = FakeBot()
        mockStatistics = BotStatisticsServiceMock()
        mockRouter = ConnectedPeerListRouterMock()
        sut = ConnectedPeerListCoordinator(bot: mockBot, statisticsService: mockStatistics, router: mockRouter)
        sut.viewDidAppear()
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
            noNamePeerConnectionInfo,
            noAboutPeerConnectionInfo,
            alicePeerConnectionInfo
        ]
        
        let publisherCompletion = await makeAwaitable(publisher: sut.$peers.collectNext())

        // Act
        await mockStatistics.statisticsPasthrough.send(newStatistics)
        let publishedPeers = try await publisherCompletion.result.get()
        
        // Assert
        XCTAssertEqual(publishedPeers.first, expectedPeers)
    }
    
    func testPublishingNewStatisticsUpdatesCurrentlyActiveProperty() async throws {
        // Arrange
        XCTAssertEqual(sut.peers, [])
        let firstPeerStatistics = PeerStatistics(
            count: 0,
            connectionCount: 0,
            identities: [],
            open: [
                ("1.1.1.1", IdentityFixture.alice.id),
                ("2.2.2.2", IdentityFixture.noAbout.id),
            ]
        )
        let firstExpectedPeers = [
            noAboutPeerConnectionInfo,
            alicePeerConnectionInfo
        ]
        var firstBotStatistics = baseStatistics
        firstBotStatistics.peer = firstPeerStatistics

        // Act
        var publisherCompletion = await makeAwaitable(publisher: sut.$peers.collectNext())
        await mockStatistics.statisticsPasthrough.send(firstBotStatistics)
        var publishedPeers = try await publisherCompletion.result.get()
        
        // Assert
        XCTAssertEqual(publishedPeers.first, firstExpectedPeers)
        
        // Rearrange
        
        // Add noName, remove Alice
        let secondPeerStatistics = PeerStatistics(
            count: 3,
            connectionCount: 2,
            identities: [],
            open: [
                ("2.2.2.2", IdentityFixture.noAbout.id),
                ("3.3.3.3", IdentityFixture.noName.id),
            ]
        )
        var inactiveAlice = alicePeerConnectionInfo
        inactiveAlice.currentlyActive = false
        let secondExpectedPeers = [
            noNamePeerConnectionInfo,
            noAboutPeerConnectionInfo,
            inactiveAlice
        ]
        var secondBotStatistics = baseStatistics
        secondBotStatistics.peer = secondPeerStatistics
        
        // React
        publisherCompletion = await makeAwaitable(publisher: sut.$peers.collectNext())
        await mockStatistics.statisticsPasthrough.send(secondBotStatistics)
        publishedPeers = try await publisherCompletion.result.get()
        
        XCTAssertEqual(publishedPeers.first, secondExpectedPeers)
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
        XCTAssertEqual(recentlyDownloadedPostDuration, 999)
    }
    
    func testPeersDoNotUpdateWhenViewNotVisible() async throws {
        // Arrange
        sut = ConnectedPeerListCoordinator(bot: mockBot, statisticsService: mockStatistics, router: mockRouter)
        var publishedPeers = [[PeerConnectionInfo]]()
        
        // Act
        let cancellable = sut.$peers.sink { newPeers in
            publishedPeers.append(newPeers)
        }
        
        await mockStatistics.statisticsPasthrough.send(baseStatistics)
        sut.viewDidAppear()
        await mockStatistics.statisticsPasthrough.send(baseStatistics)
        sut.viewDidDisappear()
        await mockStatistics.statisticsPasthrough.send(baseStatistics)
                 
        // Assert
        withExtendedLifetime(cancellable) { _ in
            XCTAssertEqual(publishedPeers.count, 1)
        }
    }
    
    func testTappingPeerCellShowsProfile() {
        // Act
        sut.peerTapped(alicePeerConnectionInfo)
        
        // Assert
        XCTAssertEqual(mockRouter.showProfileCallCount, 1)
        XCTAssertEqual(mockRouter.showProfileIdentityParameter, IdentityFixture.alice)
    }
    
    func testTappingPeerCellWithoutIdentityShowsError() {
        // Act
        sut.peerTapped(PeerConnectionInfo(
            id: "foo",
            identity: nil,
            name: nil,
            imageMetadata: nil,
            currentlyActive: true
        ))
        
        // Assert
        XCTAssertEqual(mockRouter.showProfileCallCount, 0)
        XCTAssertEqual(mockRouter.alertCallCount, 1)
    }
}
