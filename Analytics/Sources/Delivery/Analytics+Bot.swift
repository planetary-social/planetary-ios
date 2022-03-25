//
//  File.swift
//  
//
//  Created by Martin Dutra on 5/1/22.
//

import Foundation

public extension Analytics {

    struct BotRepair {
        public var function: String
        public var numberOfMessagesInDB: Int64
        public var numberOfMessagesInRepo: Int
        public var reportedAuthors: Int?
        public var reportedMessages: UInt32?

        public init(function: String, numberOfMessagesInDB: Int64, numberOfMessagesInRepo: Int) {
            self.function = function
            self.numberOfMessagesInDB = numberOfMessagesInDB
            self.numberOfMessagesInRepo = numberOfMessagesInRepo
        }
    }

    func trackBotDidSkipMessage(key: String, reason: String) {
        service.track(event: .did, element: .bot, name: "sync", params: ["Skipped": key,
                                                                         "Reason": reason])
    }

    func trackBotDidUpdateMessages(count: Int) {
        service.track(event: .did, element: .bot, name: "db_update", param: "inserted", value: "\(count)")
    }

    func trackBotDidUpdateDatabase(count: Int, firstTimestamp: Float64, lastTimestamp: Float64, lastHash: String) {
        let params: [String: Any] = ["msg.count": count,
                                     "first.timestamp": firstTimestamp,
                                     "last.timestamp": lastTimestamp,
                                     "last.hash": lastHash]
        service.track(event: .did, element: .bot, name: "db_update", params: params)
    }

    func trackBotDidRepair(databaseError: String, error: String?, repair: BotRepair) {
        var params: [String: Any] = ["sql_error": databaseError,
                                     "function": "ViewConstraints21012020",
                                     "viewdb_current": repair.numberOfMessagesInDB,
                                     "repo_messages_count": repair.numberOfMessagesInRepo] as [String: Any]
        if let error = error {
            params["repair_failed"] = error
        }
        if let reportedAuthors = repair.reportedAuthors {
            params["reported_authors"] = reportedAuthors
        }

        if let reportedMessages = repair.reportedMessages {
            params["reported_messages"] = reportedMessages
        }
        service.track(event: .did, element: .bot, name: "repair", params: params)
    }

    func trackBotDidSync(duration: TimeInterval, numberOfMessages: Int) {
        let params: [String: Any] = ["duration": duration,
                                     "number_of_messages": numberOfMessages]
        service.track(event: .did, element: .bot, name: "sync", params: params)
    }

    func trackBotDidRefresh(load: Int, duration: TimeInterval, error: Error? = nil) {
        var params: [String: Any] = ["load": load,
                                     "duration": duration]
        if let error = error {
            params["error"] = error.localizedDescription
        }
        service.track(event: .did, element: .bot, name: "refresh", params: params)
    }
}
