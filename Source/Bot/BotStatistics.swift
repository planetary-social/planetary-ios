//
//  Created by Christoph on 4/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Analytics

// MARK: - API statistics

struct BotStatistics: Equatable {

    var lastSyncDate: Date?
    var lastSyncDuration: TimeInterval = 0

    var lastRefreshDate: Date?
    var lastRefreshDuration: TimeInterval = 0

    /// The number of new posts that have been downloaded in the `recentlyDownloadedPostDuration`.
    var recentlyDownloadedPostCount = 0

    /// The number of minutes we consider "recent" for the `recentlyDownloadedPostCount`. So if this value is 15, then
    /// `recentlyDownloadedPostCount` will contain all posts 
    var recentlyDownloadedPostDuration = 15

    var repo = RepoStatistics()
    var peer = PeerStatistics()
    var db = DatabaseStatistics()
}

extension BotStatistics {

    var analyticsStatistics: Analytics.Statistics {
        var statistics = Analytics.Statistics(lastSyncDate: lastSyncDate,
                                              lastRefreshDate: lastRefreshDate)

        if repo.feedCount != -1 {
            statistics.repo = Analytics.RepoStatistics(feedCount: repo.feedCount,
                                                       messageCount: repo.messageCount,
                                                       numberOfPublishedMessages: repo.numberOfPublishedMessages,
                                                       lastHash: repo.lastHash)
        }

        if db.lastReceivedMessage != -3 {
            statistics.database = Analytics.DatabaseStatistics(
                lastReceivedMessage: db.lastReceivedMessage,
                messageCount: db.messageCount
            )
        }

        statistics.peer = Analytics.PeerStatistics(peers: peer.count,
                                                   connectedPeers: peer.connectionCount)

        return statistics
    }
}

/// Statistics for the go-ssb log
struct RepoStatistics: Equatable {

    /// Path to the repo
    let path: String

    /// Number of feeds in the repo
    let feedCount: Int

    /// Total number of messages
    let messageCount: Int

    /// Number of messages published by the user
    let numberOfPublishedMessages: Int

    /// Last message in the repo
    let lastHash: String

    init(path: String? = nil,
         feedCount: Int = -1,
         messageCount: Int = 0,
         numberOfPublishedMessages: Int = 0,
         lastHash: String = "") {
        self.path = path ?? "unknown"
        self.feedCount = feedCount
        self.messageCount = messageCount
        self.numberOfPublishedMessages = numberOfPublishedMessages
        self.lastHash = lastHash
    }
}

/// Statistics for the SQLite database
struct DatabaseStatistics: Equatable {

    let lastReceivedMessage: Int
    
    let messageCount: Int

    init(lastReceivedMessage: Int = -2, messageCount: Int = 0) {
        self.lastReceivedMessage = lastReceivedMessage
        self.messageCount = messageCount
    }
}

struct PeerStatistics: Equatable {

    let count: Int
    let connectionCount: UInt

    // name, identifier
    let identities: [(name: String, identifier: Identifier)]

    // IP, Identifier
    let currentOpen: [(name: String, identifier: Identifier)]

    init(count: Int? = 0,
         connectionCount: UInt? = 0,
         identities: [(String, String)]? = [],
         open: [(String, String)]? = []) {
        self.count = count ?? 0
        self.connectionCount = connectionCount ?? 0
        self.identities = identities ?? []
        self.currentOpen = open ?? []
    }
    
    static func == (lhs: PeerStatistics, rhs: PeerStatistics) -> Bool {
        lhs.count == rhs.count &&
        lhs.connectionCount == rhs.connectionCount &&
        lhs.identities.map { $0.0 } == rhs.identities.map { $0.0 } &&
        lhs.identities.map { $0.1 } == rhs.identities.map { $0.1 } &&
        lhs.currentOpen.map { $0.0 } == rhs.currentOpen.map { $0.0 } &&
        lhs.currentOpen.map { $0.1 } == rhs.currentOpen.map { $0.1 }
    }
}
