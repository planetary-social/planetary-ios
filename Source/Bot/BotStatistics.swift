//
//  Created by Christoph on 4/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Analytics

// MARK:- API statistics

protocol BotStatistics {

    var lastSyncDate: Date? { get }
    var lastSyncDuration: TimeInterval { get }

    var lastRefreshDate: Date? { get }
    var lastRefreshDuration: TimeInterval { get }

    var repo: RepoStatistics { get }
    var peer: PeerStatistics { get }
    var db: DatabaseStatistics { get }

}

extension BotStatistics {

    var analyticsStatistics: Analytics.Statistics {
        var statistics = Analytics.Statistics(lastSyncDate: lastSyncDate,
                                              lastRefreshDate: lastRefreshDate)
        
        if repo.feedCount != -1 {
            statistics.repo = Analytics.Statistics.RepoStatistics(feedCount: repo.feedCount,
                                                                  messageCount: repo.messageCount,
                                                                  numberOfPublishedMessages: repo.numberOfPublishedMessages,
                                                                  lastHash: repo.lastHash)
        }

        if db.lastReceivedMessage != -3 {
            statistics.db = Analytics.Statistics.DatabaseStatistics(lastReceivedMessage: db.lastReceivedMessage)
        }

        statistics.peer = Analytics.Statistics.PeerStatistics(peers: peer.count,
                                                              connectedPeers: peer.connectionCount)

        return statistics
    }

}

struct MutableBotStatistics: BotStatistics {

    var lastSyncDate: Date?
    var lastSyncDuration: TimeInterval = 0

    var lastRefreshDate: Date?
    var lastRefreshDuration: TimeInterval = 0

    var repo = RepoStatistics()
    var peer = PeerStatistics()
    var db = DatabaseStatistics()
}

struct RepoStatistics {

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

struct DatabaseStatistics {

    let lastReceivedMessage: Int

    init(lastReceivedMessage: Int = -2) {
        self.lastReceivedMessage = lastReceivedMessage
    }

}

struct PeerStatistics {

    let count: Int
    let connectionCount: UInt

    // name, identifier
    let identities: [(String, String)]

    // IP, Identifier
    let currentOpen: [(String, String)]

    init(count: Int? = 0,
         connectionCount: UInt? = 0,
         identities: [(String, String)]? = [],
         open: [(String, String)]? = [])
    {
        self.count = count ?? 0
        self.connectionCount = connectionCount ?? 0
        self.identities = identities ?? []
        self.currentOpen = open ?? []
    }
}
