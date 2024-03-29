//
//  HomeStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// This strategy acts like a Composite strategy that uses one strategy (selected by the user in the Settings screen)
/// and routes all functions through that strategy so that we have the responsibility of choosing the right strategy
/// to this class and let other parts o
final class HomeStrategy: NSObject, FeedStrategy {

    private var innerStrategy: FeedStrategy {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.object(forKey: UserDefaults.homeFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return RecentlyActivePostsAndContactsAlgorithm()
    }

    override init() {
        super.init()
    }

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        try innerStrategy.countNumberOfKeys(connection: connection, userId: userId)
    }

    func fetchMessages(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [Message] {
        try innerStrategy.fetchMessages(database: database, userId: userId, limit: limit, offset: offset)
    }

    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int {
        try innerStrategy.countNumberOfKeys(connection: connection, userId: userId, since: message)
    }

    func encode(with coder: NSCoder) { }

    init?(coder: NSCoder) { }
}
