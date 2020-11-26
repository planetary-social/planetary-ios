//
//  AnalyticsService+Bot.swift
//  Planetary
//
//  Created by Christoph on 12/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsService {

    func trackBotRefresh() {
        self.time(event: .did, element: .bot, name: AnalyticsEnums.Name.refresh.rawValue)
    }
    
    func trackBotDidRefresh(load: RefreshLoad, duration: TimeInterval, error: Error? = nil) {
        let params: AnalyticsEnums.Params = [
            "load": load.rawValue,
            "duration": duration,
            "error": error.debugDescription
        ]
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.refresh.rawValue,
                   params: params)
    }

    func trackBotSync() {
        self.time(event: .did, element: .bot, name: AnalyticsEnums.Name.sync.rawValue)
    }
    
    func trackBotDidSync(duration: TimeInterval, numberOfMessages: Int, error: Error? = nil) {
        let params: AnalyticsEnums.Params = ["duration": duration,
                                             "number_of_messages": numberOfMessages]
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.sync.rawValue,
                   params: params)
    }

    func trackBotDidStats(statistics: BotStatistics) {
        var params: AnalyticsEnums.Params = [:]

        if let lastSyncDate = statistics.lastSyncDate {
            params["Last Sync"] = lastSyncDate
        }

        if let lastRefreshDate = statistics.lastRefreshDate {
            params["Last Refresh"] = lastRefreshDate
        }

        if statistics.repo.feedCount != -1 {
            params["Feed Count"] = statistics.repo.feedCount
            params["Message Count"] = statistics.repo.messageCount
            params["Published Message Count"] = statistics.repo.numberOfPublishedMessages
            params["Last Hash"] = statistics.repo.lastHash
        }

        if statistics.db.lastReceivedMessage != -3 {
            let lastRxSeq = statistics.db.lastReceivedMessage
            params["Last Received Message"] = lastRxSeq

            if statistics.repo.feedCount != -1 {
                let diff = statistics.repo.messageCount - 1 - lastRxSeq
                params["Message Diff"] = diff
            }
        }

        params["Peers"] = statistics.peer.count
        params["Connected Peers"] = statistics.peer.connectionCount

        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.stats.rawValue,
                   params: params)
    }
}
