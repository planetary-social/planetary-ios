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
        public var db: DatabaseStatistics?
        public var peer: PeerStatistics?

        public init(lastSyncDate: Date?, lastRefreshDate: Date?) {
            self.lastSyncDate = lastSyncDate
            self.lastRefreshDate = lastRefreshDate
        }

        public struct RepoStatistics {
            public var feedCount: Int
            public var messageCount: Int
            public var numberOfPublishedMessages: Int
            public var lastHash: String

            public init(feedCount: Int, messageCount: Int, numberOfPublishedMessages: Int, lastHash: String) {
                self.feedCount = feedCount
                self.messageCount = messageCount
                self.numberOfPublishedMessages = numberOfPublishedMessages
                self.lastHash = lastHash
            }
        }

        public struct DatabaseStatistics {
            public var lastReceivedMessage: Int

            public init(lastReceivedMessage: Int) {
                self.lastReceivedMessage = lastReceivedMessage
            }
        }

        public struct PeerStatistics {
            public var peers: Int
            public var connectedPeers: UInt

            public init(peers: Int, connectedPeers: UInt) {
                self.peers = peers
                self.connectedPeers = connectedPeers
            }
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
            params["Message Count"] = repo.messageCount
            params["Published Message Count"] = repo.numberOfPublishedMessages
            params["Last Hash"] = repo.lastHash
        }

        if let db = statistics.db {
            let lastRxSeq = db.lastReceivedMessage
            params["Last Received Message"] = lastRxSeq

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
