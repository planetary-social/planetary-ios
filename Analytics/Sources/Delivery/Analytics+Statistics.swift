//
//  Analytics+Statistics.swift
//  
//
//  Created by Martin Dutra on 28/2/22.
//

import Foundation

public extension Analytics {

    struct Statistics {
        public var lastSyncDate: Date?
        public var lastRefreshDate: Date?
        public var repo: RepoStatistics?
        public var database: DatabaseStatistics?
        public var peer: PeerStatistics?

        public init(lastSyncDate: Date?, lastRefreshDate: Date?) {
            self.lastSyncDate = lastSyncDate
            self.lastRefreshDate = lastRefreshDate
        }
    }

    struct RepoStatistics {
        public var feedCount: Int
        public var messageCount: Int
        public var numberOfPublishedMessages: Int

        public init(feedCount: Int, messageCount: Int, numberOfPublishedMessages: Int) {
            self.feedCount = feedCount
            self.messageCount = messageCount
            self.numberOfPublishedMessages = numberOfPublishedMessages
        }
    }

    struct DatabaseStatistics {
        public var lastReceivedMessage: Int
        public var messageCount: Int

        public init(lastReceivedMessage: Int, messageCount: Int) {
            self.lastReceivedMessage = lastReceivedMessage
            self.messageCount = messageCount
        }
    }

    struct PeerStatistics {
        public var peers: Int
        public var connectedPeers: UInt

        public init(peers: Int, connectedPeers: UInt) {
            self.peers = peers
            self.connectedPeers = connectedPeers
        }
    }

    func trackStatistics(_ statistics: Statistics) {
        var params: [String: Any] = [:]

        if let lastSyncDate = statistics.lastSyncDate {
            params["Last Sync"] = lastSyncDate
        }

        if let lastRefreshDate = statistics.lastRefreshDate {
            params["Last Refresh"] = lastRefreshDate
        }

        if let repo = statistics.repo {
            params["Feed Count"] = repo.feedCount
            params["Repo Message Count"] = repo.messageCount
            params["Published Message Count"] = repo.numberOfPublishedMessages
        }

        if let database = statistics.database {
            let lastRxSeq = database.lastReceivedMessage
            params["Last Received Message"] = lastRxSeq
            params["Database Message Count"] = database.messageCount

            if let repo = statistics.repo {
                let diff = repo.messageCount - 1 - lastRxSeq
                params["Message Diff"] = diff
            }
        }

        if let peer = statistics.peer {
            params["Peers"] = peer.peers
            params["Connected Peers"] = peer.connectedPeers
        }

        service.track(event: .did, element: .bot, name: "stats", params: params)
    }
}
