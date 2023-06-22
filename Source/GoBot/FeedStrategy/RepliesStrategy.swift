//
//  RepliesStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 12/2/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite
import Logger

/// This algorithm returns a feed with replies to a message
final class RepliesStrategy: NSObject, FeedStrategy {

    // swiftlint:disable indentation_width
    /// SQL query to count the total number of items in the feed
    ///
    /// The WHERE clauses are as follows:
    /// - Only posts and follows (contacts)
    /// - Discard private messages
    /// - Discard hidden messages
    /// - Only follows (contacts) to people we know something about
    /// - Only posts and follows from user itsef
    /// - Discard posts and follows from the future
    private let countNumberOfKeysQuery = """
        SELECT
          COUNT(*)
        FROM
          tangles t
          JOIN messagekeys rmk ON rmk.id = t.root
          JOIN messagekeys ON messagekeys.id = t.msg_ref
          JOIN messages messages ON messages.msg_id = t.msg_ref
          JOIN authors a ON a.id = messages.author_id
        WHERE
          messages.type IN ('post', 'vote')
          AND rmk.key = :message_identifier
          AND messages.hidden = FALSE;
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
    /// - Only posts and follows (contacts)
    /// - Discard private messages
    /// - Discard hidden messages
    /// - Only follows (contacts) to people we know something about
    /// - Only posts and follows from user itsef
    /// - Discard posts and follows from the future or before the message
    ///
    /// The result is sorted by  date
    private let fetchMessagesQuery = """
        SELECT
          messages.*,
          posts.*,
          tangles.*,
          messagekeys.*,
          authors.*,
          abouts.*,
          votes.*,
          EXISTS (
            SELECT
              1
            FROM
              post_blobs
            WHERE
              post_blobs.msg_ref = messages.msg_id
          ) as has_blobs,
          EXISTS (
            SELECT
              1
            FROM
              mention_feed
            WHERE
              mention_feed.msg_ref = messages.msg_id
          ) as has_feed_mentions,
          EXISTS (
            SELECT
              1
            FROM
              mention_message
            WHERE
              mention_message.msg_ref = messages.msg_id
          ) as has_message_mentions,
          (
            SELECT
              COUNT(*)
            FROM
              tangles
            WHERE
              root = messages.msg_id
          ) as replies_count,
          (
            SELECT
              GROUP_CONCAT(abouts.image, ';')
            FROM
              tangles
              JOIN messages AS tangled_message ON tangled_message.msg_id = tangles.msg_ref
              JOIN abouts ON abouts.about_id = tangled_message.author_id
            WHERE
              tangles.root = messages.msg_id
              AND abouts.image IS NOT NULL
            LIMIT
              2
          ) as replies
        FROM
          tangles t
          JOIN messagekeys rmk ON rmk.id = t.root
          JOIN messagekeys ON messagekeys.id = t.msg_ref
          JOIN messages messages ON messages.msg_id = t.msg_ref
          JOIN authors ON authors.id = messages.author_id
          LEFT JOIN tangles ON tangles.msg_ref = messages.msg_id
          LEFT JOIN abouts ON abouts.about_id = messages.author_id
          LEFT JOIN posts ON posts.msg_ref = t.msg_ref
          LEFT JOIN votes ON votes.msg_ref = t.msg_ref
        WHERE
          messages.type IN ('post', 'vote')
          AND rmk.key = :message_identifier
          AND messages.hidden = FALSE
          AND messages.is_decrypted = FALSE
        ORDER BY
          messages.claimed_at ASC
        LIMIT
          :limit
        OFFSET
          :offset;
    """
    // swiftlint:enable indentation_width

    let identifier: MessageIdentifier

    override init() {
        self.identifier = .null
        super.init()
    }

    init(identifier: MessageIdentifier) {
        self.identifier = identifier
        super.init()
    }

    required init?(coder: NSCoder) {
        self.identifier = .null
        super.init()
    }

    func encode(with coder: NSCoder) {}

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let query = try connection.prepare(countNumberOfKeysQuery)

        let bindings: [String: Binding?] = [
            ":message_identifier": identifier
        ]

        if let count = try query.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int {
        return 0
    }

    func fetchMessages(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [Message] {
        guard let connection = try? database.checkoutConnection() else {
            Log.error("db is closed")
            return []
        }

        let query = try connection.prepare(fetchMessagesQuery)
        let bindings: [String: Binding?] = [
            ":message_identifier": identifier,
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
