//
//  PostsAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite
import Logger

// swiftlint:disable type_body_length
/// This algorithm returns a feed just with user's and follows' root posts
///
/// This algorithm is the same algorithm we used to have in production, I'm leaving this here for comparison.
/// For this reason, I didn't put effort in optimizing this algorithm even though there is room for improvement:
/// - make the query with a single string in the way PostsAndContactsStrategy does
/// - filter follows and followers in the same query
/// - fetch the number of replies in the same query
/// - remove additional queryies made after getting the results
class PostsAlgorithm: NSObject, FeedStrategy {
    // swiftlint:enable type_body_length

    var wantPrivate: Bool
    var onlyFollowed: Bool

    init(wantPrivate: Bool, onlyFollowed: Bool) {
        self.wantPrivate = wantPrivate
        self.onlyFollowed = onlyFollowed
    }
    
    required init?(coder: NSCoder) {
        wantPrivate = coder.decodeBool(forKey: "wantPrivate")
        onlyFollowed = coder.decodeBool(forKey: "onlyFollowed")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(wantPrivate, forKey: "wantPrivate")
        coder.encode(onlyFollowed, forKey: "onlyFollowed")
    }

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let posts = Table(ViewDatabaseTableNames.posts.rawValue)
        let authors = Table(ViewDatabaseTableNames.authors.rawValue)
        let msgs = Table(ViewDatabaseTableNames.messages.rawValue)

        let colMessageRef = Expression<Int64>("msg_ref")
        let colID = Expression<Int64>("id")
        let colMessageID = Expression<Int64>("msg_id")
        let colMsgType = Expression<String>("type")
        let colDecrypted = Expression<Bool>("is_decrypted")
        let colIsRoot = Expression<Bool>("is_root")
        let colHidden = Expression<Bool>("hidden")
        let colAuthorID = Expression<Int64>("author_id")

        var query = posts
            .join(msgs, on: msgs[colMessageID] == posts[colMessageRef])
            .join(authors, on: authors[colID] == msgs[colAuthorID])
            .filter(colMsgType == "post")
            .filter(colIsRoot == true)
            .filter(colHidden == false)
            .filter(colDecrypted == false)

        if onlyFollowed {
            query = try self.filterOnlyFollowedPeople(query: query, connection: connection, userId: userId)
        } else {
            query = try self.filterNotFollowingPeople(query: query, connection: connection, userId: userId)
        }
        return try connection.scalar(query.count)
    }

    func fetchKeyValues(database: ViewDatabase, userId: Int64, limit: Int, offset: Int?) throws -> [KeyValue] {
        guard let connection = database.getOpenDB() else {
            Log.error("db is closed")
            return []
        }
        
        let colClaimedAt = Expression<Double>("claimed_at")

        var query = self.basicRecentPostsQuery(limit: limit, wantPrivate: wantPrivate, offset: offset)
            .order(colClaimedAt.desc)

        if onlyFollowed {
            query = try self.filterOnlyFollowedPeople(query: query, connection: connection, userId: userId)
        } else {
            query = try self.filterNotFollowingPeople(query: query, connection: connection, userId: userId)
        }

        let feedOfMsgs = try self.mapQueryToKeyValue(query: query, database: database)

        return try self.addNumberOfPeopleReplied(msgs: feedOfMsgs, connection: connection)
    }

    func fetchKeys(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [MessageIdentifier] {
        let posts = Table(ViewDatabaseTableNames.posts.rawValue)
        let authors = Table(ViewDatabaseTableNames.authors.rawValue)
        let msgs = Table(ViewDatabaseTableNames.messages.rawValue)
        let msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)

        let colMessageRef = Expression<Int64>("msg_ref")
        let colID = Expression<Int64>("id")
        let colMessageID = Expression<Int64>("msg_id")
        let colMsgType = Expression<String>("type")
        let colDecrypted = Expression<Bool>("is_decrypted")
        let colIsRoot = Expression<Bool>("is_root")
        let colHidden = Expression<Bool>("hidden")
        let colKey = Expression<MessageIdentifier>("key")
        let colAuthorID = Expression<Int64>("author_id")

        var query = msgs
            .join(posts, on: posts[colMessageRef] == msgs[colMessageID])
            .join(msgKeys, on: msgKeys[colID] == msgs[colMessageID])
            .join(authors, on: authors[colID] == msgs[colAuthorID])
            .filter(colMsgType == "post")           // only posts (no votes or contact messages)
            .filter(colDecrypted == wantPrivate)
            .filter(colHidden == false)

        if let offset = offset {
            query = query.limit(limit, offset: offset)
        } else {
            query = query.limit(limit)
        }

        query = query.filter(colIsRoot == true)   // only thread-starting posts (no replies)

        query = query.order(colMessageID.desc)

        if onlyFollowed {
            query = try self.filterOnlyFollowedPeople(query: query, connection: connection, userId: userId)
        } else {
            query = try self.filterNotFollowingPeople(query: query, connection: connection, userId: userId)
        }

        return try connection.prepare(query).compactMap { keyRow in
            try keyRow.get(colKey)
        }
    }

    private func basicRecentPostsQuery(
        limit: Int,
        wantPrivate: Bool,
        onlyRoots: Bool = true,
        offset: Int? = nil
    ) -> Table {
        let authors = Table(ViewDatabaseTableNames.authors.rawValue)
        let posts = Table(ViewDatabaseTableNames.posts.rawValue)
        let msgs = Table(ViewDatabaseTableNames.messages.rawValue)
        let msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)
        let tangles = Table(ViewDatabaseTableNames.tangles.rawValue)
        let abouts = Table(ViewDatabaseTableNames.abouts.rawValue)
        let aboutAuthor = abouts.alias("author_about")

        let colMessageRef = Expression<Int64>("msg_ref")

        let colID = Expression<Int64>("id")
        let colMessageID = Expression<Int64>("msg_id")
        let colMsgType = Expression<String>("type")
        let colClaimedAt = Expression<Double>("claimed_at")
        let colDecrypted = Expression<Bool>("is_decrypted")
        let colIsRoot = Expression<Bool>("is_root")
        let colHidden = Expression<Bool>("hidden")
        let colAboutID = Expression<Int64>("about_id")
        let colAuthorID = Expression<Int64>("author_id")

        var query = msgs
            .join(posts, on: posts[colMessageRef] == msgs[colMessageID])
            .join(.leftOuter, tangles, on: tangles[colMessageRef] == msgs[colMessageID])
            .join(msgKeys, on: msgKeys[colID] == msgs[colMessageID])
            .join(authors, on: authors[colID] == msgs[colAuthorID])
            .join(.leftOuter, aboutAuthor, on: aboutAuthor[colAboutID] == msgs[colAuthorID])
            .filter(colMsgType == "post")           // only posts (no votes or contact messages)
            .filter(colDecrypted == wantPrivate)
            .filter(colHidden == false)
            .filter(colClaimedAt <= Date().millisecondsSince1970)

        if let offset = offset {
            query = query.limit(limit, offset: offset)
        } else {
            query = query.limit(limit)
        }
        if onlyRoots {
            query = query.filter(colIsRoot == true)   // only thread-starting posts (no replies)
        }
        return query
    }

    private func filterOnlyFollowedPeople(query: Table, connection: Connection, userId: Int64) throws -> Table {
        return query
            .filter(
                Expression(literal: """
                (authors.author IN (SELECT followed_authors.author FROM contacts
                JOIN authors AS followed_authors ON contacts.contact_id == followed_authors.id
                WHERE contacts.author_id = \(userId) AND contacts.state == 1))
                """
                )
            )
    }

    private func filterNotFollowingPeople(query: Table, connection: Connection, userId: Int64) throws -> Table {
        return query
            .filter(
                Expression(literal: """
                (authors.author NOT IN
                    (SELECT followed_and_blocked_authors.author FROM contacts
                    JOIN authors AS followed_and_blocked_authors ON contacts.contact_id == followed_and_blocked_authors.id
                    WHERE contacts.author_id = \(userId)
                    AND (contacts.state == -1 OR contacts.state == 1))
                )
                AND authors.id != \(userId)
                """
                )
            )
    }

    private func mapQueryToKeyValue(query: Table, database: ViewDatabase) throws -> [KeyValue] {
        guard let connection = database.getOpenDB() else {
            Log.error("db is closed")
            return []
        }
        
        return try connection.prepare(query).compactMap { keyValueRow in
            return try KeyValue(row: keyValueRow, database: database)
        }
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
            let imgHash = try blobRow.get(colIdentifier)

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
                identifier: imgHash,
                name: try? blobRow.get(colName),
                metadata: meta
            )
        }
        return blobs
    }

    private func loadMentions(for msgID: Int64, connection: Connection) throws -> [Mention] {
        let colMessageRef = Expression<Int64>("msg_ref")
        let colFeedID = Expression<Int64>("feed_id")
        let colLinkID = Expression<Int64>("link_id")
        let mentionsMsg = Table(ViewDatabaseTableNames.mentionsMsg.rawValue)
        let mentionsFeed = Table(ViewDatabaseTableNames.mentionsFeed.rawValue)
        let colName = Expression<String?>("name")

        let feedQry = mentionsFeed.where(colMessageRef == msgID)
        let feedMentions: [Mention] = try connection.prepare(feedQry).map { feedMentionRow in
            let feedID = try feedMentionRow.get(colFeedID)
            let feed = try self.author(from: feedID, connection: connection)
            return Mention(
                link: feed,
                name: try feedMentionRow.get(colName) ?? ""
            )
        }

        let msgMentionQry = mentionsMsg.where(colMessageRef == msgID)
        let msgMentions: [Mention] = try connection.prepare(msgMentionQry).map { messageMentionRow in
            let linkID = try messageMentionRow.get(colLinkID)
            return Mention(
                link: try self.msgKey(id: linkID, connection: connection),
                name: ""
            )
        }

        return feedMentions + msgMentions
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

    private func addNumberOfPeopleReplied(msgs: [KeyValue], connection: Connection) throws -> KeyValues {
        let messages = Table(ViewDatabaseTableNames.messages.rawValue)
        let tangles = Table(ViewDatabaseTableNames.tangles.rawValue)
        let authors = Table(ViewDatabaseTableNames.authors.rawValue)
        let abouts = Table(ViewDatabaseTableNames.abouts.rawValue)
        let colName = Expression<String?>("name")
        let colImage = Expression<BlobIdentifier?>("image")
        let colDescr = Expression<String?>("description")
        let colAuthor = Expression<Identity>("author")
        let colMsgType = Expression<String>("type")
        let colMessageID = Expression<Int64>("msg_id")
        let colMessageRef = Expression<Int64>("msg_ref")
        let colAuthorID = Expression<Int64>("author_id")
        let colID = Expression<Int64>("id")
        let colRoot = Expression<Int64>("root")
        let colAboutID = Expression<Int64>("about_id")

        var keyValues: KeyValues = []
        for var message in msgs {
            let msgID = try self.msgID(of: message.key, connection: connection)

            let replies = tangles
                .select(colAuthorID.distinct, colAuthor, colName, colDescr, colImage)
                .join(messages, on: messages[colMessageID] == tangles[colMessageRef])
                .join(authors, on: messages[colAuthorID] == authors[colID])
                .join(abouts, on: authors[colID] == abouts[colAboutID])
                .filter(colMsgType == ContentType.post.rawValue || colMsgType == ContentType.vote.rawValue)
                .filter(colRoot == msgID)

            let count = try connection.scalar(replies.count)

            var abouts: [About] = []
            for replyRow in try connection.prepare(replies.limit(3, offset: 0)) {
                let about = About(
                    about: replyRow[colAuthor],
                    name: replyRow[colName],
                    description: replyRow[colDescr],
                    imageLink: replyRow[colImage]
                )
                abouts += [about]
            }

            message.metadata.replies.count = count
            message.metadata.replies.abouts = abouts
            keyValues.append(message)
        }
        return keyValues
    }

    private func msgID(of key: MessageIdentifier, make: Bool = false, connection: Connection) throws -> Int64 {
        let msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)
        let colID = Expression<Int64>("id")
        let colKey = Expression<MessageIdentifier>("key")
        let colHashedKey = Expression<String>("hashed")

        if let msgKeysRow = try connection.pluck(msgKeys.filter(colKey == key)) {
            return msgKeysRow[colID]
        }

        guard make else { throw ViewDatabaseError.unknownMessage(key) }

        return try connection.run(msgKeys.insert(colKey <- key, colHashedKey <- key.sha256hash))
    }
}
