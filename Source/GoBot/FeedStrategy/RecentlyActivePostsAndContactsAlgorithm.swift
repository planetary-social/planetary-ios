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
                 AND contacts.state != -1
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
        WITH
          last_reply AS (
            SELECT
              COALESCE(
                (
                  SELECT
                    tangled_message.claimed_at
                  FROM
                    tangles
                    JOIN messages AS tangled_message ON tangles.msg_ref = tangled_message.msg_id
                  WHERE
                    tangles.root = messages.msg_id
                    AND tangled_message.claimed_at < STRFTIME('%s') * 1000
                    AND tangled_message.type = 'post'
                  ORDER BY
                    tangled_message.claimed_at DESC
                  LIMIT
                    1
                ), messages.claimed_at
              ) as replied_at,
              messagekeys.key AS key
            FROM
              messages
              JOIN messagekeys ON messagekeys.id = messages.msg_id
          )
        SELECT
          COUNT(messagekeys.key)
        FROM
          messages
          JOIN last_reply ON last_reply.key = messagekeys.key
          JOIN authors ON authors.id = messages.author_id
          JOIN messagekeys ON messagekeys.id = messages.msg_id
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
                contacts.author_id = ?
                AND contacts.state = 1
            )
            OR authors.id = ?
          )
          AND authors.author NOT IN (
            SELECT
              key
            FROM
              pubs
          )
          AND last_reply.replied_at BETWEEN (
            SELECT
              last_reply.replied_at + 1
            FROM
              last_reply
            WHERE
              last_reply.key = ?
          ) AND STRFTIME('%s') * 1000;
    """
    // swiftlint:enable indentation_width

    // swiftlint:disable indentation_width
    private let fetchKeyValuesQuery = """
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
               ) as replies,
               (SELECT COALESCE(
                    (SELECT tangled_message.claimed_at
                    FROM tangles
                    JOIN messages AS tangled_message ON tangles.msg_ref == tangled_message.msg_id
                    WHERE tangles.root == messages.msg_id
                    AND tangled_message.claimed_at < ?
                    AND tangled_message.type = 'post'
                    ORDER BY tangled_message.claimed_at DESC LIMIT 1),
                    messages.claimed_at
               )) as last_reply
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
                 AND contacts.state != -1
                )
        AND (authors.author IN (SELECT authors.author FROM contacts
                               JOIN authors ON contacts.contact_id == authors.id
                               WHERE contacts.author_id = ? AND contacts.state == 1)
             OR authors.id == ?)
        AND authors.author NOT IN (SELECT key FROM pubs)
        AND claimed_at < ?
        ORDER BY last_reply DESC
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

    func fetchKeyValues(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [KeyValue] {
        guard let connection = database.getOpenDB() else {
            Log.error("db is closed")
            return []
        }
        
        let query = try connection.prepare(fetchKeyValuesQuery)
        let bindings: [Binding?] = [
            Date().millisecondsSince1970,
            userId,
            userId,
            Date().millisecondsSince1970,
            limit,
            offset ?? 0
        ]
        let keyValues = try query.bind(bindings).prepareRowIterator().map { keyValueRow -> KeyValue? in
            try buildKeyValue(keyValueRow: keyValueRow, database: database)
        }
        let compactKeyValues = keyValues.compactMap { $0 }
        return compactKeyValues
    }

    private func buildKeyValue(keyValueRow: Row, database: ViewDatabase) throws -> KeyValue? {
        try KeyValue(row: keyValueRow, database: database)
    }
}
