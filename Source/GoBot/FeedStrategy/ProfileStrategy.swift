//
//  ProfileStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 20/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

final class ProfileStrategy: NSObject, FeedStrategy {

    let identity: Identity

    private var innerStrategy: FeedStrategy {
        isStar ? OneHopFeedAlgorithm(identity: identity) : NoHopFeedAlgorithm(identity: identity)
    }

    private var isStar: Bool {
        let pubs = (AppConfiguration.current?.communityPubs ?? []) +
            (AppConfiguration.current?.systemPubs ?? [])
        return pubs.contains { $0.feed == identity }
    }

    init(identity: Identity) {
        self.identity = identity
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

    func encode(with coder: NSCoder) {

    }

    init?(coder: NSCoder) {
        nil
    }
}
