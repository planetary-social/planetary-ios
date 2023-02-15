//
//  HashtagAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 29/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite
import Logger

final class HashtagAlgorithm: NSObject, FeedStrategy {
    // swiftlint:disable indentation_width
    /// SQL query to count the total number of items in the feed
    ///
    /// The WHERE clauses are as follows:
    /// - The name of the hashtag matches the text we want to look for
    private let countNumberOfKeysQuery = """
        SELECT
          COUNT(*)
        FROM
          channel_assignments ca
          JOIN channels c ON c.id = ca.chan_ref
          JOIN messagekeys keys ON keys.id = ca.msg_ref
          JOIN messages msgs ON msgs.msg_id = ca.msg_ref
          JOIN authors ON authors.id = msgs.author_id
        WHERE
          c.name = :name
    """
    // swiftlint:enable indentation_width

    // swiftlint:disable indentation_width
    /// SQL query to return the feed's keyvalues
    ///
    /// The SELECT clauses are as follows:
    /// - All data from message, post, contact, tangle, messagekey, author and about of the author
    /// - The identified of the followed author if the message is a follow (contact)
    /// - A bool column indicating if the message has blobs
    /// - A bool column indicating if the message has feed mentions
    /// - A bool column indicating if the message has message mentions
    /// - The number of replies to the message
    ///
    /// The WHERE clauses are as follows:
    /// - The name of the hashtag matches the text we want to look for
    ///
    /// The result is sorted by message id so that we do a quick sort that normally puts newer messages on top
    /// while not doing an expensive sort by date
    private let fetchMessagesQuery = """
        SELECT
          *,
          EXISTS (
            SELECT
              1
            FROM
              post_blobs
            WHERE
              post_blobs.msg_ref = msgs.msg_id
          ) as has_blobs,
          EXISTS (
            SELECT
              1
            FROM
              mention_feed
            WHERE
              mention_feed.msg_ref = msgs.msg_id
          ) as has_feed_mentions,
          EXISTS (
            SELECT
              1
            FROM
              mention_message
            WHERE
              mention_message.msg_ref = msgs.msg_id
          ) as has_message_mentions,
          (
            SELECT
              COUNT(*)
            FROM
              tangles
            WHERE
              root = msgs.msg_id
          ) as replies_count,
          (
            SELECT
              GROUP_CONCAT(abouts.image, ';')
            FROM
              tangles
              JOIN messages AS tangled_message ON tangled_message.msg_id = tangles.msg_ref
              JOIN abouts ON abouts.about_id = tangled_message.author_id
            WHERE
              tangles.root = msgs.msg_id
              AND abouts.image IS NOT NULL
            LIMIT
              2
          ) as replies
        FROM
          channel_assignments ca
          JOIN channels c ON c.id = ca.chan_ref
          JOIN messagekeys keys ON keys.id = ca.msg_ref
          JOIN messages msgs ON msgs.msg_id = ca.msg_ref
          JOIN authors ON authors.id = msgs.author_id
          LEFT JOIN abouts ON abouts.about_id = msgs.author_id
          LEFT JOIN tangles ON tangles.msg_ref = ca.msg_ref
          LEFT JOIN posts ON posts.msg_ref = ca.msg_ref
        WHERE
          c.name = :name
        ORDER BY
          msg_id DESC
        LIMIT
          :limit
        OFFSET
          :offset;
    """
    // swiftlint:enable indentation_width

    let hashtag: Hashtag

    override init() {
        self.hashtag = Hashtag(name: "")
        super.init()
    }

    init(hashtag: Hashtag) {
        self.hashtag = hashtag
        super.init()
    }

    required init?(coder: NSCoder) {
        self.hashtag = Hashtag(name: "")
        super.init()
    }

    func encode(with coder: NSCoder) {}

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let query = try connection.prepare(countNumberOfKeysQuery)

        let bindings: [String: Binding?] = [
            ":name": hashtag.name
        ]

        if let count = try query.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int {
        0
    }

    func fetchMessages(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [Message] {
        guard let connection = try? database.checkoutConnection() else {
            Log.error("db is closed")
            return []
        }

        let query = try connection.prepare(fetchMessagesQuery)
        let bindings: [String: Binding?] = [
            ":name": hashtag.name,
            ":limit": limit,
            ":offset": offset ?? 0
        ]
        let messages = try query.bind(bindings).prepareRowIterator().map { messageRow -> Message? in
            try buildMessage(messageRow: messageRow, database: database)
        }
        let compactMessages = messages.compactMap { $0 }
        return compactMessages
    }

    private func buildMessage(messageRow: Row, database: ViewDatabase) throws -> Message? {
        try Message(row: messageRow, database: database)
    }
}
