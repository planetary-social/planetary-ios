//
//  PostsAndContactsAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite
import Logger

/// This algorithm returns a feed with user's and follows' posts, and follows' following other users in the network
///
/// It doesn't include pubs follows and posts in the feed
final class PostsAndContactsAlgorithm: NSObject, FeedStrategy {

    // swiftlint:disable indentation_width
    /// SQL query to count the total number of items in the feed
    ///
    /// This query should be as fast as possible so only required joins and where clauses where used.
    /// The result should be the same as the number of items returned by the other two queries in this class.
    /// The where clauses are as follows:
    /// - Only posts and follows (contacts) are considered
    /// - Discard private messages
    /// - Discard hidden messages
    /// - Only root posts
    /// - Only follows (contacts) to people we know something about and discard follows to pubs
    /// - Only posts and follows from user's follows or from user itsef
    /// - Discard posts and follows from pubs
    /// - Discard posts and follows from the future
    private let countNumberOfKeysQuery = """
        SELECT COUNT(*)
        FROM messages
        JOIN authors ON authors.id == messages.author_id
        LEFT JOIN posts ON messages.msg_id == posts.msg_ref
        LEFT JOIN contacts ON messages.msg_id == contacts.msg_ref
        LEFT JOIN abouts AS contact_about ON contact_about.about_id == contacts.contact_id
        LEFT JOIN authors AS contact_author ON contact_author.id == contacts.contact_id
        WHERE messages.type IN ('post', 'contact')
        AND messages.is_decrypted == false
        AND messages.hidden == false
        AND (type <> 'post' OR posts.is_root == true)
        AND (type <> 'contact'
             OR (contact_about.about_id IS NOT NULL
                 AND contact_author.author NOT IN (SELECT key FROM pubs))
                 AND contacts.state == 1
                )
        AND (authors.author IN (
                SELECT authors.author FROM contacts
                JOIN authors ON contacts.contact_id == authors.id
                WHERE contacts.author_id = ? AND contacts.state == 1
            ) OR authors.id == ?)
        AND authors.author NOT IN (SELECT key FROM pubs)
        AND claimed_at < ?;
    """
    // swiftlint:enable indentation_width

    // swiftlint:disable indentation_width
    /// SQL query to return the feed's keys
    ///
    /// This query should be as fast as possible so only required joins and where clauses where used.
    /// The result should be the same as the number of items returned by the other two queries in this class.
    /// The where clauses are as follows:
    /// - Only posts and follows (contacts) are considered
    /// - Discard private messages
    /// - Discard hidden messages
    /// - Only root posts
    /// - Only follows (contacts) to people we know something about and discard follows to pubs
    /// - Only posts and follows from user's follows or from user itsef
    /// - Discard posts and follows from pubs
    /// - Discard posts and follows from the future
    ///
    /// The result is sorted by  date
    private let countNumberOfKeysSinceQuery = """
        WITH
          last_post AS (
            SELECT
              m.claimed_at as claimed_at,
              mk.key as key
            FROM
              messages m
              JOIN messagekeys mk ON mk.id = m.msg_id
          ),
          pub_list AS (
            SELECT
              key
            FROM
              pubs
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
            type <> 'post'
            OR posts.is_root = true
          )
          AND (
            type <> 'contact'
            OR (
              contact_about.about_id IS NOT NULL
              AND contact_author.author NOT IN pub_list
            )
          )
          AND (
            authors.author IN (
              SELECT
                authors.author
              FROM
                contacts
                JOIN authors ON contacts.contact_id = authors.id
              WHERE
                contacts.author_id = ?
                AND contacts.state = 1
            )
            OR authors.id = ?
          )
          AND authors.author NOT IN pub_list
          AND claimed_at BETWEEN (
            SELECT
              last_post.claimed_at + 1
            FROM
              last_post
            WHERE
              last_post.key = ?
            LIMIT
              1
          )
          AND STRFTIME('%s') * 1000;
        """
    // swiftlint:enable indentation_width

    // swiftlint:disable indentation_width
    /// SQL query to return the feed's keyvalues
    ///
    /// This query should be as fast as possible and contain just the minimum data
    /// to display it in the Home or Discover feed. The result should be the same as the number of items
    /// returned by the other two queries in this class.
    ///
    /// The select clauses are as follows:
    /// - All data from message, post, contact, tangle, messagekey, author and about of the author
    /// - The identified of the followed author if the message is a follow (contact)
    /// - A bool column indicating if the message has blobs
    /// - A bool column indicating if the message has feed mentions
    /// - A bool column indicating if the message has message mentions
    /// - The number of replies to the message
    ///
    /// The where clauses are as follows:
    /// - Only posts and follows (contacts) are considered
    /// - Discard private messages
    /// - Discard hidden messages
    /// - Only root posts
    /// - Only follows (contacts) to people we know something about and discard follows to pubs
    /// - Only posts and follows from user's follows or from user itsef
    /// - Discard posts and follows from pubs
    /// - Discard posts and follows from the future
    ///
    /// The result is sorted by  date
    private let fetchMessagesQuery = """
        SELECT messages.*,
               posts.*,
               contacts.*,
               contact_about.about_id,
               tangles.*,
               messagekeys.*,
               authors.*,
               author_about.*,
               contact_author.author AS contact_identifier,
               EXISTS (SELECT 1 FROM post_blobs WHERE post_blobs.msg_ref == messages.msg_id) as has_blobs,
               EXISTS (SELECT 1 FROM mention_feed WHERE mention_feed.msg_ref == messages.msg_id) as has_feed_mentions,
               EXISTS (
                   SELECT 1
                   FROM mention_message
                   WHERE mention_message.msg_ref == messages.msg_id
               ) as has_message_mentions,
               (SELECT COUNT(*)
                FROM tangles
                WHERE root == messages.msg_id
               ) as replies_count,
               (SELECT GROUP_CONCAT(authors.author, ';')
                FROM tangles
                JOIN messages AS tangled_message ON tangled_message.msg_id == tangles.msg_ref
                JOIN authors ON authors.id == tangled_message.author_id
                WHERE tangles.root == messages.msg_id LIMIT 3
               ) as replies
        FROM messages
        LEFT JOIN posts ON messages.msg_id == posts.msg_ref
        LEFT JOIN contacts ON messages.msg_id == contacts.msg_ref
        LEFT JOIN tangles ON tangles.msg_ref == messages.msg_id
        JOIN messagekeys ON messagekeys.id == messages.msg_id
        JOIN authors ON authors.id == messages.author_id
        LEFT JOIN abouts AS author_about ON author_about.about_id == messages.author_id
        LEFT JOIN authors AS contact_author ON contact_author.id == contacts.contact_id
        LEFT JOIN abouts AS contact_about ON contact_about.about_id == contacts.contact_id
        WHERE type IN ('post', 'contact')
        AND is_decrypted == false
        AND hidden == false
        AND (type <> 'post' OR posts.is_root == true)
        AND (type <> 'contact'
             OR (contact_about.about_id IS NOT NULL
                 AND contact_author.author NOT IN (SELECT key FROM pubs))
                 AND contacts.state == 1
                )
        AND (authors.author IN (SELECT authors.author FROM contacts
                               JOIN authors ON contacts.contact_id == authors.id
                               WHERE contacts.author_id = ? AND contacts.state == 1)
             OR authors.id == ?)
        AND authors.author NOT IN (SELECT key FROM pubs)
        AND claimed_at < ?
        ORDER BY claimed_at DESC
        LIMIT ? OFFSET ?;
    """
    // swiftlint:enable indentation_width
    
    override init() {
        super.init()
    }
    required init?(coder: NSCoder) {}
    func encode(with coder: NSCoder) {}

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let query = try connection.prepare(countNumberOfKeysQuery)

        let bindings: [Binding?] = [
            userId,
            userId,
            Date().millisecondsSince1970
        ]

        if let count = try query.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int {
        let query = try connection.prepare(countNumberOfKeysSinceQuery)

        let bindings: [Binding?] = [
            userId,
            userId,
            message
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
        let bindings: [Binding?] = [userId, userId, Date().millisecondsSince1970, limit, offset ?? 0]
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
