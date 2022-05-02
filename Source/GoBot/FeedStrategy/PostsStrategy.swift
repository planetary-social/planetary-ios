//
//  PostsStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

class PostsStrategy: FeedStrategy {

    var connection: Connection
    var currentUserID: Int64
    var wantPrivate: Bool
    var onlyFollowed: Bool

    init(connection: Connection, currentUserID: Int64, wantPrivate: Bool, onlyFollowed: Bool) {
        self.connection = connection
        self.currentUserID = currentUserID
        self.wantPrivate = wantPrivate
        self.onlyFollowed = onlyFollowed
    }

    func countNumberOfRecentPosts() throws -> Int {
        try recentPosts(limit: 100_000, offset: 0).count
    }

    func recentIdentifiers(limit: Int, offset: Int?) throws -> [MessageIdentifier] {
        try recentPosts(limit: limit, offset: offset).map { $0.key }
    }

    func recentPosts(limit: Int, offset: Int?) throws -> [KeyValue] {
        let authorsClause = onlyFollowed ? "IN" : "NOT IN"
        let qry = try connection.prepare("""
        SELECT messages.*,
               posts.*,
               contacts.*,
               tangles.*,
               messagekeys.*,
               authors.*,
               author_about.*,
               (SELECT COUNT(*) FROM tangles WHERE root == messages.msg_id) as replies_count
        FROM messages
        LEFT JOIN posts ON messages.msg_id == posts.msg_ref
        LEFT JOIN contacts ON messages.msg_id == contacts.msg_ref
        LEFT JOIN tangles ON tangles.msg_ref == messages.msg_id
        JOIN messagekeys ON messagekeys.id == messages.msg_id
        JOIN authors ON authors.id == messages.author_id
        LEFT JOIN abouts AS author_about ON author_about.about_id == messages.author_id
        LEFT JOIN abouts AS contact_about ON contact_about.about_id == contacts.contact_id
        WHERE type IN ('post')
        AND is_decrypted == ?
        AND hidden == false
        AND posts.is_root == true
        AND authors.author \(authorsClause) (SELECT authors2.author FROM contacts
                               JOIN authors ON contacts.author_id == authors.id
                               JOIN authors authors2 ON contacts.contact_id == authors2.id
                               WHERE authors.id == ? OR authors2.id == ?)
        AND claimed_at < ?
        ORDER BY claimed_at DESC
        LIMIT ? OFFSET ?;
        """)

        let bindings: [Binding?] = [
            wantPrivate,
            self.currentUserID,
            self.currentUserID,
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
                    rootKey = try self.msgKey(id: rootID)
                }

                let p = Post(
                    blobs: try self.loadBlobs(for: msgID),
                    mentions: try self.loadMentions(for: msgID),
                    root: rootKey,
                    text: try row.get(colText)
                )

                c = Content(from: p)

            case ContentType.vote.rawValue:

                let lnkID = try row.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID)

                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID)

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
                    let name = try row.get(Expression<String?>("contact_name"))
                    let cc = Contact(contact: name ?? "unknown", following: following)
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
            keyValue.metadata.replies.count = try row.get(Expression<Int>("replies_count"))
            keyValue.metadata.isPrivate = try row.get(colDecrypted)
            return keyValue
        }

        let compactKeyValues = keyValues.compactMap { $0 }
        return compactKeyValues
    }

    private func msgKey(id: Int64) throws -> MessageIdentifier {
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

    private func loadBlobs(for msgID: Int64) throws -> [Blob] {
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

    private func loadMentions(for msgID: Int64) throws -> [Mention] {
        let colMessageRef = Expression<Int64>("msg_ref")
        let colFeedID = Expression<Int64>("feed_id")
        let colLinkID = Expression<Int64>("link_id")
        let mentions_msg = Table(ViewDatabaseTableNames.mentionsMsg.rawValue)
        let mentions_feed = Table(ViewDatabaseTableNames.mentionsFeed.rawValue)
        let colName = Expression<String?>("name")

        let feedQry = mentions_feed.where(colMessageRef == msgID)
        let feedMentions: [Mention] = try connection.prepare(feedQry).map {
            row in

            let feedID = try row.get(colFeedID)
            let feed = try self.author(from: feedID)

            return Mention(
                link: feed,
                name: try row.get(colName) ?? ""
            )
        }

        let msgMentionQry = mentions_msg.where(colMessageRef == msgID)
        let msgMentions: [Mention] = try connection.prepare(msgMentionQry).map {
            row in

            let linkID = try row.get(colLinkID)
            return Mention(
                link: try self.msgKey(id: linkID),
                name: ""
            )
        }
        /*
        // TODO: We don't =populate mentions_images... so why are we looking it up?
        let imgMentionQry = self.mentions_image
            .where(colMessageRef == msgID)
            .where(colImage != "")
        let imgMentions: [Mention] = try db.prepare(imgMentionQry).map {
            row in

            let img = try row.get(colImage)

            return Mention(
                link: img!, // illegal insert
                name: try row.get(colName) ?? ""
            )
        }
        */

        return feedMentions + msgMentions
    }

    private func author(from id: Int64) throws -> Identity {
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
