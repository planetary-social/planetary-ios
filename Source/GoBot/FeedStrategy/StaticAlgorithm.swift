//
//  StaticAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 13/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

final class StaticAlgorithm: NSObject, FeedStrategy {
    let messages: [Message]

    init(messages: [Message]) {
        self.messages = messages
    }

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        messages.count
    }

    func fetchMessages(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [Message] {
        messages
    }

    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int {
        0
    }

    func encode(with coder: NSCoder) { }

    init?(coder: NSCoder) {
        nil
    }
}
