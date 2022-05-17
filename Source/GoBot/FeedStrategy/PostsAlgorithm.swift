//
//  PostsAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

// swiftlint:disable type_body_length
/// This algorithm returns a feed just with user's and follows' posts
///
/// This algorithm is the same algorithm we used to have in production, I'm leaving this here for comparison.
/// For this reason, I didn't put effort in optimizing this algorithm even though there is room for improvement:
/// - make the query with a single string in the way PostsAndContactsStrategy does
/// - filter follows and followers in the same query
/// - fetch the number of replies in the same query
/// - remove additional queryies made after getting the results
class PostsAlgorithm: FeedStrategy {
    // swiftlint:enable type_body_length

    var wantPrivate: Bool
    var onlyFollowed: Bool

    init(wantPrivate: Bool, onlyFollowed: Bool) {
        self.wantPrivate = wantPrivate
        self.onlyFollowed = onlyFollowed
    }

    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int {
        let posts = Table(ViewDatabaseTableNames.posts.rawValue)
        let msgs = Table(ViewDatabaseTableNames.messages.rawValue)

        let colMessageRef = Expression<Int64>("msg_ref")
        let colMessageID = Expression<Int64>("msg_id")
        let colMsgType = Expression<String>("type")
        let colDecrypted = Expression<Bool>("is_decrypted")
        let colIsRoot = Expression<Bool>("is_root")
        let colHidden = Expression<Bool>("hidden")

        var query = posts
            .join(msgs, on: msgs[colMessageID] == posts[colMessageRef])
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

    func fetchKeyValues(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [KeyValue] {
        let colClaimedAt = Expression<Double>("claimed_at")

        var query = self.basicRecentPostsQuery(limit: limit, wantPrivate: wantPrivate, offset: offset)
            .order(colClaimedAt.desc)

        if onlyFollowed {
            query = try self.filterOnlyFollowedPeople(query: query, connection: connection, userId: userId)
        } else {
            query = try self.filterNotFollowingPeople(query: query, connection: connection, userId: userId)
        }

        let feedOfMsgs = try self.mapQueryToKeyValue(query: query, connection: connection)

        return try self.addNumberOfPeopleReplied(msgs: feedOfMsgs, connection: connection)
    }

    func fetchKeys(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [MessageIdentifier] {
        let posts = Table(ViewDatabaseTableNames.posts.rawValue)
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

        var query = msgs
            .join(posts, on: posts[colMessageRef] == msgs[colMessageID])
            .join(msgKeys, on: msgKeys[colID] == msgs[colMessageID])
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
            .join(.leftOuter, abouts, on: abouts[colAboutID] == msgs[colAuthorID])
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
        let contacts = Table(ViewDatabaseTableNames.contacts.rawValue)
        let colAuthorID = Expression<Int64>("author_id")
        let colContactID = Expression<Int64>("contact_id")
        let colContactState = Expression<Int>("state")

        // get the list of people that the active user follows
        let myFollowsQry = contacts
            .select(colContactID)
            .filter(colAuthorID == userId)
            .filter(colContactState == 1)
        var myFollows: [Int64] = [userId] // and from self as well
        for followRow in try connection.prepare(myFollowsQry) {
            myFollows.append(followRow[colContactID])
        }
        return query.filter(myFollows.contains(colAuthorID))    // authored by one of our follows
    }

    private func filterNotFollowingPeople(query: Table, connection: Connection, userId: Int64) throws -> Table {
        let contacts = Table(ViewDatabaseTableNames.contacts.rawValue)
        let colAuthorID = Expression<Int64>("author_id")
        let colContactID = Expression<Int64>("contact_id")
        let colContactState = Expression<Int>("state")

        // get the list of people that the active user follows
        let myFollowsQry = contacts
            .select(colContactID)
            .filter(colAuthorID == userId)
            .filter(colContactState == 1)
        var myFollows: [Int64] = [userId] // and from self as well
        for followRow in try connection.prepare(myFollowsQry) {
            myFollows.append(followRow[colContactID])
        }
        return query.filter(!(myFollows.contains(colAuthorID)))    // authored by one of our follows
    }

    // swiftlint:disable function_body_length
    private func mapQueryToKeyValue(query: Table, connection: Connection) throws -> [KeyValue] {
        // swiftlint:enable function_body_length
        let msgs = Table(ViewDatabaseTableNames.messages.rawValue)
        let abouts = Table(ViewDatabaseTableNames.abouts.rawValue)
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

        return try connection.prepare(query).compactMap { keyValueRow in
            let msgID = try keyValueRow.get(colMessageID)
            let msgKey = try keyValueRow.get(colKey)
            let msgAuthor = try keyValueRow.get(colAuthor)
            var content: Content
            let type = try keyValueRow.get(msgs[colMsgType])
            switch type {
            case ContentType.post.rawValue:
                var rootKey: Identifier?
                if let rootID = try keyValueRow.get(colRootMaybe) {
                    rootKey = try self.msgKey(id: rootID, connection: connection)
                }
                let post = Post(
                    blobs: try self.loadBlobs(for: msgID, connection: connection),
                    mentions: try self.loadMentions(for: msgID, connection: connection),
                    root: rootKey,
                    text: try keyValueRow.get(colText)
                )
                content = Content(from: post)
            case ContentType.vote.rawValue:
                let lnkID = try keyValueRow.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID, connection: connection)
                let rootID = try keyValueRow.get(colRoot)
                let rootKey = try self.msgKey(id: rootID, connection: connection)
                let contentVote = ContentVote(
                    link: lnkKey,
                    value: try keyValueRow.get(colValue),
                    root: rootKey,
                    branches: []
                )
                content = Content(from: contentVote)
            case ContentType.contact.rawValue:
                if let state = try? keyValueRow.get(colContactState) {
                    let following = state == 1
                    let contentContact = Contact(contact: msgAuthor, following: following)
                    content = Content(from: contentContact)
                } else {
                    // Contacts stores only the latest message
                    // So, an old follow that was later unfollowed won't appear here.
                    return nil
                }
            default:
                throw ViewDatabaseError.unexpectedContentType(type)
            }
            let value = Value(
                author: msgAuthor,
                content: content,
                hash: "sha256", // only currently supported
                previous: nil,
                sequence: try keyValueRow.get(colSequence),
                signature: "verified_by_go-ssb",
                timestamp: try keyValueRow.get(colClaimedAt)
            )
            var keyValue = KeyValue(
                key: msgKey,
                value: value,
                timestamp: try keyValueRow.get(colReceivedAt)
            )
            keyValue.metadata.author.about = About(
                about: msgAuthor,
                name: try keyValueRow.get(abouts[colName]),
                description: try keyValueRow.get(colDescr),
                imageLink: try keyValueRow.get(colImage)
            )
            keyValue.metadata.isPrivate = try keyValueRow.get(colDecrypted)
            return keyValue
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
