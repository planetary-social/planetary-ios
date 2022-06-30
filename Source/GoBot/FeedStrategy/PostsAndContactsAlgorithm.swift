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
class PostsAndContactsAlgorithm: NSObject, FeedStrategy {

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
    private let fetchKeysQuery = """
        SELECT messagekeys.key
        FROM messages
        JOIN authors ON authors.id == messages.author_id
        JOIN messagekeys ON messagekeys.id == messages.msg_id
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
        AND claimed_at < ?
        ORDER BY messages.claimed_at DESC
        LIMIT ? OFFSET ?;
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
    private let fetchKeyValuesQuery = """
        SELECT messages.*,
               posts.*,
               contacts.*,
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
                 AND contacts.state != -1
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

    func fetchKeys(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [MessageIdentifier] {
        let query = try connection.prepare(fetchKeysQuery)

        let bindings: [Binding?] = [
            userId,
            userId,
            Date().millisecondsSince1970,
            limit,
            offset ?? 0
        ]

        let colKey = Expression<MessageIdentifier>("key")
        return try query.bind(bindings).prepareRowIterator().map { keyRow -> MessageIdentifier in
            try keyRow.get(colKey)
        }
    }

    func fetchKeyValues(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [KeyValue] {
        guard let connection = database.getOpenDB() else {
            Log.error("db is closed")
            return []
        }
        
        let query = try connection.prepare(fetchKeyValuesQuery)
        let bindings: [Binding?] = [userId, userId, Date().millisecondsSince1970, limit, offset ?? 0]
        let keyValues = try query.bind(bindings).prepareRowIterator().map { keyValueRow -> KeyValue? in
            try buildKeyValue(keyValueRow: keyValueRow, database: database)
        }
        let compactKeyValues = keyValues.compactMap { $0 }
        return compactKeyValues
    }

    private func buildKeyValue(keyValueRow: Row, database: ViewDatabase) throws -> KeyValue? {
        return try KeyValue(row: keyValueRow, database: database)
    }

    private func buildPostContent(keyValueRow: Row, connection: Connection) throws -> Content {
        let colMessageID = Expression<Int64>("msg_id")
        let colRootMaybe = Expression<Int64?>("root")
        let colText = Expression<String>("text")

        let msgID = try keyValueRow.get(colMessageID)

        var rootKey: Identifier?
        if let rootID = try keyValueRow.get(colRootMaybe) {
            rootKey = try self.msgKey(id: rootID, connection: connection)
        }

        let hasBlobs = try keyValueRow.get(Expression<Bool>("has_blobs"))
        let blobs = hasBlobs ? try self.loadBlobs(for: msgID, connection: connection) : []

        var mentions = [Mention]()
        let hasFeedMentions = try keyValueRow.get(Expression<Bool>("has_feed_mentions"))
        if hasFeedMentions {
            mentions.append(contentsOf: try self.loadFeedMentions(for: msgID, connection: connection))
        }
        let hasMessageMentions = try keyValueRow.get(Expression<Bool>("has_message_mentions"))
        if hasMessageMentions {
            mentions.append(contentsOf: try self.loadMessageMentions(for: msgID, connection: connection))
        }

        let postContent = Post(
            blobs: blobs,
            mentions: mentions,
            root: rootKey,
            text: try keyValueRow.get(colText)
        )

        return Content(from: postContent)
    }

    private func buildVoteContent(keyValueRow: Row, connection: Connection) throws -> Content {
        let colRoot = Expression<Int64>("root")
        let colLinkID = Expression<Int64>("link_id")
        let colValue = Expression<Int>("value")
        let colExpression = Expression<String?>("expression")

        let lnkID = try keyValueRow.get(colLinkID)
        let lnkKey = try self.msgKey(id: lnkID, connection: connection)

        let rootID = try keyValueRow.get(colRoot)
        let rootKey = try self.msgKey(id: rootID, connection: connection)
        let expression = try keyValueRow.get(colExpression)

        let voteContent = ContentVote(
            link: lnkKey,
            value: try keyValueRow.get(colValue),
            expression: expression,
            root: rootKey,
            branches: []
        )

        return Content(from: voteContent)
    }

    private func buildContactContent(keyValueRow: Row) throws -> Content? {
        let colContactState = Expression<Int>("state")

        if let state = try? keyValueRow.get(colContactState) {
            let following = state == 1
            let identifier = try keyValueRow.get(Expression<Identifier>("contact_identifier"))
            let contactContent = Contact(contact: identifier, following: following)
            return Content(from: contactContent)
        }
        // Contacts stores only the latest message
        // So, an old follow that was later unfollowed won't appear here.
        return nil
    }

    private func msgKey(id: Int64, connection: Connection) throws -> MessageIdentifier {
        let msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)
        let colID = Expression<Int64>("id")
        let colKey = Expression<MessageIdentifier>("key")
        var msgKey: MessageIdentifier
        if let msgKeysRow = try connection.pluck(msgKeys.filter(colID == id)) {
            msgKey = msgKeysRow[colKey]
        } else {
            throw ViewDatabaseError.unknownReferenceID(id)
        }
        return msgKey
    }

    private func loadBlobs(for msgID: Int64, connection: Connection) throws -> [Blob] {
        let postBlobs = Table(ViewDatabaseTableNames.postBlobs.rawValue)
        let colMessageRef = Expression<Int64>("msg_ref")
        let colIdentifier = Expression<String>("identifier")
        let colName = Expression<String?>("name")
        let colMetaBytes = Expression<Int?>("meta_bytes")
        let colMetaWidth = Expression<Int?>("meta_widht")
        let colMetaHeight = Expression<Int?>("meta_height")
        let colMetaMimeType = Expression<String?>("meta_mime_type")
        let colMetaAverageColorRGB = Expression<Int?>("meta_average_color_rgb")

        let query = postBlobs.where(colMessageRef == msgID)
            .filter(colMetaMimeType == "image/jpeg" || colMetaMimeType == "image/png" )

        let blobs: [Blob] = try connection.prepare(query).map { blobRow in
            var dimensions: Blob.Metadata.Dimensions?
            if let width = try blobRow.get(colMetaWidth) {
                if let height = try blobRow.get(colMetaHeight) {
                    dimensions = Blob.Metadata.Dimensions(width: width, height: height)
                }
            }

            let meta = Blob.Metadata(
                averageColorRGB: try blobRow.get(colMetaAverageColorRGB),
                dimensions: dimensions,
                mimeType: try blobRow.get(colMetaMimeType),
                numberOfBytes: try blobRow.get(colMetaBytes)
            )

            return Blob(
                identifier: try blobRow.get(colIdentifier),
                name: try? blobRow.get(colName),
                metadata: meta
            )
        }
        return blobs
    }

    private func loadFeedMentions(for msgID: Int64, connection: Connection) throws -> [Mention] {
        let colMessageRef = Expression<Int64>("msg_ref")
        let colFeedID = Expression<Int64>("feed_id")
        let mentionsFeed = Table(ViewDatabaseTableNames.mentionsFeed.rawValue)
        let colName = Expression<String?>("name")

        let feedQry = mentionsFeed.where(colMessageRef == msgID)
        let feedMentions: [Mention] = try connection.prepare(feedQry).map { mentionRow in

            let feedID = try mentionRow.get(colFeedID)
            let feed = try self.author(from: feedID, connection: connection)

            return Mention(
                link: feed,
                name: try mentionRow.get(colName) ?? ""
            )
        }

        return feedMentions
    }

    private func loadMessageMentions(for msgID: Int64, connection: Connection) throws -> [Mention] {
        let colMessageRef = Expression<Int64>("msg_ref")
        let colLinkID = Expression<Int64>("link_id")
        let mentionsMsg = Table(ViewDatabaseTableNames.mentionsMsg.rawValue)
        let msgMentionQry = mentionsMsg.where(colMessageRef == msgID)
        let msgMentions: [Mention] = try connection.prepare(msgMentionQry).map { mentionRow in
            let linkID = try mentionRow.get(colLinkID)
            return Mention(
                link: try self.msgKey(id: linkID, connection: connection),
                name: ""
            )
        }

        return msgMentions
    }

    private func author(from id: Int64, connection: Connection) throws -> Identity {
        let authors = Table(ViewDatabaseTableNames.authors.rawValue)
        let colID = Expression<Int64>("id")
        let colAuthor = Expression<Identity>("author")

        var authorKey: Identity
        if let msgKeysRow = try connection.pluck(authors.filter(colID == id)) {
            authorKey = msgKeysRow[colAuthor]
        } else {
            throw ViewDatabaseError.unknownReferenceID(id)
        }
        return authorKey
    }
}
