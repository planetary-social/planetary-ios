//
//  ProfileStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 20/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// This strategy acts like a Composite strategy that uses the most adequate strategy for displaying a list of
/// messages for an identity (ie. in the Profile screen).
final class ProfileStrategy: NSObject, FeedStrategy {

    let identity: Identity

    private var innerStrategy: FeedStrategy {
        isStar ? OneHopFeedAlgorithm(identity: identity) : NoHopFeedAlgorithm(identity: identity)
    }

    private var isStar: Bool {
        let pubs = AppConfiguration.current?.systemPubs ?? []
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
        coder.encode(identity, forKey: "identity")
    }

    init?(coder: NSCoder) {
        guard let decodedIdentity = coder.decodeObject(forKey: "identity") as? String else {
            return nil
        }
        identity = decodedIdentity
    }
}
