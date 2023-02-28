//
//  File.swift
//  
//
//  Created by Martin Dutra on 5/1/22.
//

import Foundation

public extension Analytics {

    func trackBotDidSkipMessage(key: String, reason: String) {
        service.track(event: .did, element: .bot, name: "sync", params: ["Skipped": key, "Reason": reason])
    }

    func trackBotDidUpdateDatabase(count: Int, firstTimestamp: Float64, lastTimestamp: Float64, lastHash: String) {
        let params: [String: Any] = [
            "msg.count": count,
            "first.timestamp": firstTimestamp,
            "last.timestamp": lastTimestamp,
            "last.hash": lastHash
        ]
        service.track(event: .did, element: .bot, name: "db_update", params: params)
    }

    func trackDidDropDatabase() {
        service.track(event: .did, element: .bot, name: "drop_database")
    }
    
    func trackDidStartBotMigration() {
        service.track(event: .did, element: .bot, name: "migration_start")
    }
    
    func trackDidFailBotMigration(errorCode: Int64) {
        let params: [String: Any] = ["errorCode": errorCode]
        service.track(event: .did, element: .bot, name: "migration_failed", params: params)
    }
    
    func trackDidFinishBotMigration() {
        service.track(event: .did, element: .bot, name: "migration_completed")
    }
    
    func trackBotDidChangeHomeFeedStrategy(to strategyName: String) {
        let params = ["strategy": strategyName]
        service.track(event: .did, element: .bot, name: "changeHomeFeedStrategy", params: params)
    }

    func trackBotDidChangeDiscoveryFeedStrategy(to strategyName: String) {
        let params = ["strategy": strategyName]
        service.track(event: .did, element: .bot, name: "changeDiscoverFeedStrategy", params: params)
    }

    func trackBotDidOptimizeSQLite() {
        service.track(event: .did, element: .bot, name: "optimizeSQLite")
    }
}
