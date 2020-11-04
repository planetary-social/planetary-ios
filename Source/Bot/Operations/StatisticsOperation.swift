//
//  StatisticsOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 6/30/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class StatisticsOperation: AsynchronousOperation {

    private(set) var result: Result<BotStatistics, Error> = .failure(AppError.unexpected)

    override func main() {
        Log.info("RefreshOperation started.")

        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. RefreshOperation finished.")
            self.result = .failure(BotError.notLoggedIn)
            self.finish()
            return
        }

        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.statistics(queue: queue) { [weak self] statistics in
            Log.info("StatisticsOperation finished.")

            if let lastSyncDate = statistics.lastSyncDate {
                let minutesSinceLastSync = floor(lastSyncDate.timeIntervalSinceNow / 60)
                Log.debug("Last sync: \(minutesSinceLastSync) minutes ago")
            }

            if let lastRefreshDate = statistics.lastRefreshDate {
                let minutesSinceLastRefresh = floor(lastRefreshDate.timeIntervalSinceNow / 60)
                Log.debug("Last refresh: \(minutesSinceLastRefresh) minutes ago")
            }

            if statistics.repo.feedCount != -1 {
                Log.debug("Feed count: \(statistics.repo.feedCount)")
                Log.debug("Message count: \(statistics.repo.messageCount)")
                Log.debug("Published message count: \(statistics.repo.numberOfPublishedMessages)")
            }

            if statistics.db.lastReceivedMessage != -3 {
                let lastRxSeq = statistics.db.lastReceivedMessage
                Log.debug("Last received message: \(lastRxSeq)")

                if statistics.repo.feedCount != -1 {
                    let diff = statistics.repo.messageCount - 1 - lastRxSeq
                    Log.debug("Message diff: \(diff)")
                }
            }

            Log.debug("Peers: \(statistics.peer.count)")
            Log.debug("Connected peers: \(statistics.peer.connectionCount)")

            Analytics.shared.identify(statistics: statistics)
            Analytics.shared.trackBotDidStats(statistics: statistics)
            
            let currentNumberOfPublishedMessages = statistics.repo.numberOfPublishedMessages
            if let configuration = AppConfiguration.current,
                let botIdentity = Bots.current.identity,
                let configIdentity = configuration.identity,
                botIdentity == configIdentity,
                currentNumberOfPublishedMessages > -1,
                configuration.numberOfPublishedMessages <= currentNumberOfPublishedMessages {
                configuration.numberOfPublishedMessages = currentNumberOfPublishedMessages
                configuration.apply()
                var appConfigurations = AppConfigurations.current
                if let index = appConfigurations.firstIndex(of: configuration) {
                    appConfigurations[index] = configuration
                }
                appConfigurations.save()
            }

            self?.result = .success(statistics)
            self?.finish()
        }
    }

}
