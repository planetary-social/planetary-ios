//
//  NoHopFeedAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 28/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite
import Logger

/// This algorithm returns a feed with user's posts, replies and follows
final class NoHopFeedAlgorithm: NSObject, FeedStrategy {

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
          messages
          JOIN authors ON authors.id = messages.author_id
          LEFT JOIN posts ON messages.msg_id = posts.msg_ref
          LEFT JOIN contacts ON messages.msg_id = contacts.msg_ref
          LEFT JOIN abouts AS contact_about ON contact_about.about_id = contacts.contact_id
          LEFT JOIN authors AS contact_author ON contact_author.id = contacts.contact_id
        WHERE
          messages.type IN ('post', 'contact')
          AND messages.is_decrypted = false
          AND messages.hidden = false
          AND (
            type <> 'contact'
            OR contact_about.about_id IS NOT NULL
          )
          AND authors.author = :identity_key
          AND claimed_at < STRFTIME('%s') * 1000 + 1000;
    """
    // swiftlint:enable indentation_width

    // swiftlint:disable indentation_width
    /// SQL query to return the number of items in the feed after a certain message
    ///
    /// The WHERE clauses are as follows:
    /// - Only posts and follows (contacts)
    /// - Discard private messages
    /// - Discard hidden messages
    /// - Only follows (contacts) to people we know something about
    /// - Only posts and follows from user itsef
    /// - Discard posts and follows from the future or before the message
    private let countNumberOfKeysSinceQuery = """
        WITH
          last_message AS (
            SELECT
              m.claimed_at as claimed_at
            FROM
              messages m
              JOIN messagekeys mk ON mk.id = m.msg_id
            WHERE
              mk.key = :message_key
            LIMIT
              1
          )
        SELECT
          COUNT(*)
        FROM
          messages
          JOIN authors ON authors.id = messages.author_id
          LEFT JOIN posts ON messages.msg_id = posts.msg_ref
          LEFT JOIN contacts ON messages.msg_id = contacts.msg_ref
          LEFT JOIN abouts AS contact_about ON contact_about.about_id = contacts.contact_id
          LEFT JOIN authors AS contact_author ON contact_author.id = contacts.contact_id
        WHERE
          messages.type IN ('post', 'contact')
          AND messages.is_decrypted = false
          AND messages.hidden = false
          AND (
            type <> 'contact'
            OR contact_about.about_id IS NOT NULL
          )
          AND authors.author = :identity_key
          AND claimed_at BETWEEN (
            SELECT
              claimed_at + 1
            FROM
              last_message
          )
          AND STRFTIME('%s') * 1000 + 1000;
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
          contacts.*,
          contact_about.about_id,
          tangles.*,
          messagekeys.*,
          authors.*,
          author_about.*,
          contact_author.author AS contact_identifier,
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
          messages
          LEFT JOIN posts ON messages.msg_id = posts.msg_ref
          LEFT JOIN contacts ON messages.msg_id = contacts.msg_ref
          LEFT JOIN tangles ON tangles.msg_ref = messages.msg_id
          JOIN messagekeys ON messagekeys.id = messages.msg_id
          JOIN authors ON authors.id = messages.author_id
          LEFT JOIN abouts AS author_about ON author_about.about_id = messages.author_id
          LEFT JOIN authors AS contact_author ON contact_author.id = contacts.contact_id
          LEFT JOIN abouts AS contact_about ON contact_about.about_id = contacts.contact_id
        WHERE
          type IN ('post', 'contact')
          AND is_decrypted = false
          AND hidden = false
          AND (
            type <> 'contact'
            OR contact_about.about_id IS NOT NULL
          )
          AND authors.author = :identity_key
          AND claimed_at < STRFTIME('%s') * 1000 + 1000
        ORDER BY
          claimed_at DESC
        LIMIT
          :limit
        OFFSET
          :offset;
    """
    // swiftlint:enable indentation_width

    let identity: Identity

    override init() {
        self.identity = .null
        super.init()
    }

    init(identity: Identity) {
        self.identity = identity
        super.init()
    }

    required init?(coder: NSCoder) {
        self.identity = .null
        super.init()
    }
    func encode(with coder: NSCoder) {}

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let query = try connection.prepare(countNumberOfKeysQuery)

        let bindings: [String: Binding?] = [
            ":identity_key": identity
        ]

        if let count = try query.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int {
        let query = try connection.prepare(countNumberOfKeysSinceQuery)

        let bindings: [String: Binding?] = [
            ":identity_key": identity,
            ":message_key": message
        ]

        if let count = try query.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func fetchMessages(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [Message] {
        guard let connection = try? database.checkoutConnection() else {
            Log.error("db is closed")
            return []
        }

        let query = try connection.prepare(fetchMessagesQuery)
        let bindings: [String: Binding?] = [
            ":identity_key": identity,
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
