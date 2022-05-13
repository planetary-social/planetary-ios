//
//  PostsAndContactsAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// This algorithm returns a feed with user's and follows' posts, and follows' following other users in the network
///
/// It doesn't include pubs follows and posts in the feed
class PostsAndContactsAlgorithm: FeedStrategy {

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let qry = try connection.prepare("""
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
        AND (type <> 'contact' OR (contact_about.about_id IS NOT NULL AND contact_author.author NOT IN (SELECT key FROM pubs)))
        AND (authors.author IN (SELECT authors.author FROM contacts
                               JOIN authors ON contacts.contact_id == authors.id
                               WHERE contacts.author_id = ? AND contacts.state == 1)
             OR authors.id == ?)
        AND authors.author NOT IN (SELECT key FROM pubs)
        AND claimed_at < ?;
        """)

        let bindings: [Binding?] = [
            userId,
            userId,
            Date().millisecondsSince1970
        ]

        if let count = try qry.scalar(bindings) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func fetchKeys(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [MessageIdentifier] {
        let qry = try connection.prepare("""
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
        AND (type <> 'contact' OR (contact_about.about_id IS NOT NULL AND contact_author.author NOT IN (SELECT key FROM pubs)))
        AND (authors.author IN (SELECT authors.author FROM contacts
                               JOIN authors ON contacts.contact_id == authors.id
                               WHERE contacts.author_id = ? AND contacts.state == 1)
             OR authors.id == ?)
        AND authors.author NOT IN (SELECT key FROM pubs)
        AND claimed_at < ?
        ORDER BY messages.claimed_at DESC
        LIMIT ? OFFSET ?;
        """)

        let bindings: [Binding?] = [
            userId,
            userId,
            Date().millisecondsSince1970,
            limit,
            offset ?? 0
        ]

        let colKey = Expression<MessageIdentifier>("key")
        return try qry.bind(bindings).prepareRowIterator().map { row -> MessageIdentifier in
            try row.get(colKey)
        }
    }

    func fetchKeyValues(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [KeyValue] {
        let qry = try connection.prepare("""
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
               EXISTS (SELECT 1 FROM mention_message WHERE mention_message.msg_ref == messages.msg_id) as has_message_mentions,
               (SELECT COUNT(*) FROM tangles WHERE root == messages.msg_id) as replies_count,
               (SELECT GROUP_CONCAT(authors.author, ';') FROM tangles JOIN messages AS tangled_message ON tangled_message.msg_id == tangles.msg_ref JOIN authors ON authors.id == tangled_message.author_id WHERE tangles.root == messages.msg_id LIMIT 3) as replies
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
        AND (type <> 'contact' OR (contact_about.about_id IS NOT NULL AND contact_author.author NOT IN (SELECT key FROM pubs)))
        AND (authors.author IN (SELECT authors.author FROM contacts
                               JOIN authors ON contacts.contact_id == authors.id
                               WHERE contacts.author_id = ? AND contacts.state == 1)
             OR authors.id == ?)
        AND authors.author NOT IN (SELECT key FROM pubs)
        AND claimed_at < ?
        ORDER BY claimed_at DESC
        LIMIT ? OFFSET ?;
        """)

        let bindings: [Binding?] = [
            userId,
            userId,
            Date().millisecondsSince1970,
            limit,
            offset ?? 0
        ]

        let colMessageID = Expression<Int64>("msg_id")
        let colRootMaybe = Expression<Int64?>("root")
        let colAuthor = Expression<Identity>("author")
        let colKey = Expression<MessageIdentifier>("key")
        let colMsgType = Expression<String>("type")
        let colText = Expression<String>("text")
        let colLinkID = Expression<Int64>("link_id")
        let colRoot = Expression<Int64>("root")
        let colContactState = Expression<Int>("state")
        let colSequence = Expression<Int>("sequence")
        let colClaimedAt = Expression<Double>("claimed_at")
        let colReceivedAt = Expression<Double>("received_at")
        let colName = Expression<String?>("name")
        let colImage = Expression<BlobIdentifier?>("image")
        let colDescr = Expression<String?>("description")
        let colDecrypted = Expression<Bool>("is_decrypted")
        let colValue = Expression<Int>("value")

        let keyValues = try qry.bind(bindings).prepareRowIterator().map { row -> KeyValue? in
            let msgID = try row.get(colMessageID)

            let msgKey = try row.get(colKey)
            let msgAuthor = try row.get(colAuthor)

            var c: Content

            let type = try row.get(colMsgType)

            switch type {
            case ContentType.post.rawValue:

                var rootKey: Identifier?
                if let rootID = try row.get(colRootMaybe) {
                    rootKey = try self.msgKey(id: rootID, connection: connection)
                }

                let hasBlobs = try row.get(Expression<Bool>("has_blobs"))
                let blobs = hasBlobs ? try self.loadBlobs(for: msgID, connection: connection) : []

                var mentions = [Mention]()
                let hasFeedMentions = try row.get(Expression<Bool>("has_feed_mentions"))
                if hasFeedMentions {
                    mentions.append(contentsOf: try self.loadFeedMentions(for: msgID, connection: connection))
                }
                let hasMessageMentions = try row.get(Expression<Bool>("has_message_mentions"))
                if hasMessageMentions {
                    mentions.append(contentsOf: try self.loadMessageMentions(for: msgID, connection: connection))
                }

                let p = Post(
                    blobs: blobs,
                    mentions: mentions,
                    root: rootKey,
                    text: try row.get(colText)
                )

                c = Content(from: p)

            case ContentType.vote.rawValue:

                let lnkID = try row.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID, connection: connection)

                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID, connection: connection)

                let cv = ContentVote(
                    link: lnkKey,
                    value: try row.get(colValue),
                    root: rootKey,
                    branches: [] // TODO: branches for root
                )

                c = Content(from: cv)
            case ContentType.contact.rawValue:
                if let state = try? row.get(colContactState) {
                    let following = state == 1
                    let identifier = try row.get(Expression<Identifier>("contact_identifier"))
                    let cc = Contact(contact: identifier, following: following)
                    c = Content(from: cc)
                } else {
                    // Contacts stores only the latest message
                    // So, an old follow that was later unfollowed won't appear here.
                    return nil
                }
            default:
                throw ViewDatabaseError.unexpectedContentType(type)
            }

            let v = Value(
                author: msgAuthor,
                content: c,
                hash: "sha256", // only currently supported
                previous: nil, // TODO: .. needed at this level?
                sequence: try row.get(colSequence),
                signature: "verified_by_go-ssb",
                timestamp: try row.get(colClaimedAt)
            )
            var keyValue = KeyValue(
                key: msgKey,
                value: v,
                timestamp: try row.get(colReceivedAt)
            )
            keyValue.metadata.author.about = About(
                about: msgAuthor,
                name: try row.get(colName),
                description: try row.get(colDescr),
                imageLink: try row.get(colImage)
            )
            let numberOfReplies = try row.get(Expression<Int>("replies_count"))
            let replies = try row.get(Expression<String?>("replies"))
            let abouts = replies?.split(separator: ";").map { About(about: String($0)) } ?? []
            keyValue.metadata.replies.count = numberOfReplies
            keyValue.metadata.replies.abouts = abouts
            keyValue.metadata.isPrivate = try row.get(colDecrypted)
            return keyValue
        }

        let compactKeyValues = keyValues.compactMap { $0 }
        return compactKeyValues
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
        let post_blobs = Table(ViewDatabaseTableNames.postBlobs.rawValue)
        let colMessageRef = Expression<Int64>("msg_ref")
        let colIdentifier = Expression<String>("identifier")
        let colName = Expression<String?>("name")
        let colMetaBytes = Expression<Int?>("meta_bytes")
        let colMetaWidth = Expression<Int?>("meta_widht")
        let colMetaHeight = Expression<Int?>("meta_height")
        let colMetaMimeType = Expression<String?>("meta_mime_type")
        let colMetaAverageColorRGB = Expression<Int?>("meta_average_color_rgb")

        let qry = post_blobs.where(colMessageRef == msgID)
            .filter(colMetaMimeType == "image/jpeg" || colMetaMimeType == "image/png" )

        let blobs: [Blob] = try connection.prepare(qry).map {
            row in
            let img_hash = try row.get(colIdentifier)

            var dim: Blob.Metadata.Dimensions?
            if let w = try row.get(colMetaWidth) {
                if let h = try row.get(colMetaHeight) {
                    dim = Blob.Metadata.Dimensions(width: w, height: h)
                }
            }

            let meta = Blob.Metadata(
                averageColorRGB: try row.get(colMetaAverageColorRGB),
                dimensions: dim,
                mimeType: try row.get(colMetaMimeType),
                numberOfBytes: try row.get(colMetaBytes))

            return Blob(
                identifier: img_hash,
                name: try? row.get(colName),
                metadata: meta
            )
        }
        return blobs
    }

    private func loadFeedMentions(for msgID: Int64, connection: Connection) throws -> [Mention] {
        let colMessageRef = Expression<Int64>("msg_ref")
        let colFeedID = Expression<Int64>("feed_id")
        let mentions_feed = Table(ViewDatabaseTableNames.mentionsFeed.rawValue)
        let colName = Expression<String?>("name")

        let feedQry = mentions_feed.where(colMessageRef == msgID)
        let feedMentions: [Mention] = try connection.prepare(feedQry).map {
            row in

            let feedID = try row.get(colFeedID)
            let feed = try self.author(from: feedID, connection: connection)

            return Mention(
                link: feed,
                name: try row.get(colName) ?? ""
            )
        }

        return feedMentions
    }

    private func loadMessageMentions(for msgID: Int64, connection: Connection) throws -> [Mention] {
        let colMessageRef = Expression<Int64>("msg_ref")
        let colLinkID = Expression<Int64>("link_id")
        let mentions_msg = Table(ViewDatabaseTableNames.mentionsMsg.rawValue)

        let msgMentionQry = mentions_msg.where(colMessageRef == msgID)
        let msgMentions: [Mention] = try connection.prepare(msgMentionQry).map {
            row in

            let linkID = try row.get(colLinkID)
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
