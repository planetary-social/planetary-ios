//
//  File.swift
//  
//
//  Created by Martin Dutra on 5/1/22.
//

import Foundation

public extension Analytics {

    func trackBotDidSkipMessage(key: String, reason: String) {
        service.track(event: .did, element: .bot, name: "sync", params: ["Skipped": key,
                                                                         "Reason": reason])
    }

    func trackBotDidUpdateMessages(count: Int) {
        service.track(event: .did, element: .bot, name: "db_update", param: "inserted", value: "\(count)")
    }

    func trackBodDidUpdateDatabase(count: Int, firstTimestamp: Float64, lastTimestamp: Float64, lastHash: String) {
        let params = ["msg.count": count,
                      "first.timestamp": firstTimestamp,
                      "last.timestamp": lastTimestamp,
                      "last.hash": lastHash] as [String : Any]
        service.track(event: .did, element: .bot, name: "db_update", params: params)
    }

    func trackBotDidRepair(databaseError: String, error: String?, numberOfMessagesInDB: Int64, numberOfMessagesInRepo: UInt, reportedAuthors: Int?, reportedMessages: UInt32?) {
        var params: [String: Any] = ["sql_error": databaseError,
                                     "function": "ViewConstraints21012020",
                                     "viewdb_current": numberOfMessagesInDB,
                                     "repo_messages_count": numberOfMessagesInRepo] as [String: Any]
        if let error = error {
            params["repair_failed"] = error
        }
        if let reportedAuthors = reportedAuthors {
            params["reported_authors"] = reportedAuthors
        }

        if let reportedMessages = reportedMessages {
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
