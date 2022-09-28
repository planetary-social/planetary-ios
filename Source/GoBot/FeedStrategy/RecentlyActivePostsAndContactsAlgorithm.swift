//
//  RecentlyActivePostsAndContactsAlgorithm.swift
//  Planetary
//
//  Created by Matt Lorentz on 17/5/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite
import Logger

/// This algorithm returns a feed with user's and follows' posts, and follows' following other users in the network.
/// If a root post is replied to it will be boosted back up to the top of the feed.
///
/// It doesn't include pubs follows and posts in the feed.
///
/// NOTE: This has a lot of code copied from PostsAndContactsAlgorithm. We should factor it out. (#564)
class RecentlyActivePostsAndContactsAlgorithm: NSObject, FeedStrategy {

    // swiftlint:disable indentation_width
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
    private let countNumberOfKeysSinceQuery = """
        SELECT
          COUNT(messages.msg_id),
          (SELECT :since_time) as since_time
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
              AND contact_author.author NOT IN (
                SELECT
                  key
                FROM
                  pubs
              )
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
                contacts.author_id = :user_id
                AND contacts.state = 1
            )
            OR authors.id = :user_id
          )
          AND authors.author NOT IN (SELECT key FROM pubs)
          AND last_activity_time > since_time;
    """
    // swiftlint:enable indentation_width

    // swiftlint:disable indentation_width
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
        ORDER BY last_activity_time DESC
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

    func countNumberOfKeys(connection: Connection, userId: Int64, since messageKey: MessageIdentifier) throws -> Int {
        /// Fetch the last active time of the `since` message
        let lastActiveTimeQuery = try connection.prepare(
            """
            SELECT last_activity_time
            FROM messages
            JOIN messagekeys ON messagekeys.id == messages.msg_id
            WHERE messagekeys.key = :message_key;
            """
        )
        let lastActiveTime = try lastActiveTimeQuery.scalar([":message_key": messageKey]) as? Float64
        
        let countQuery = try connection.prepare(countNumberOfKeysSinceQuery)
        
        let bindings: [String: Binding?] = [
            ":since_time": lastActiveTime,
            ":user_id": userId,
        ]

        if let count = try countQuery.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func fetchMessages(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [Message] {
        guard let connection = database.getOpenDB() else {
            Log.error("db is closed")
            return []
        }
        
        let query = try connection.prepare(fetchMessagesQuery)
        let bindings: [Binding?] = [
            userId,
            userId,
            Date().millisecondsSince1970,
            limit,
            offset ?? 0
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
