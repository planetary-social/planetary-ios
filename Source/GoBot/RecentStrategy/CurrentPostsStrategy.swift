//
//  CurrentPostsStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

class CurrentPostsStrategy: RecentStrategy {

    var connection: Connection
    var currentUserID: Int64

    init(connection: Connection, currentUserID: Int64) {
        self.connection = connection
        self.currentUserID = currentUserID
    }

    func recentPosts(limit: Int, offset: Int?, wantPrivate: Bool, onlyFollowed: Bool) throws -> [KeyValue] {
        let colClaimedAt = Expression<Double>("claimed_at")

        var qry = self.basicRecentPostsQuery(limit: limit, wantPrivate: wantPrivate, offset: offset)
            .order(colClaimedAt.desc)

        if onlyFollowed {
            qry = try self.filterOnlyFollowedPeople(qry: qry)
        } else {
            qry = try self.filterNotFollowingPeople(qry: qry)
        }

        let feedOfMsgs = try self.mapQueryToKeyValue(qry: qry)

        return try self.addNumberOfPeopleReplied(msgs: feedOfMsgs)
    }

    private func basicRecentPostsQuery(limit: Int, wantPrivate: Bool, onlyRoots: Bool = true, offset: Int? = nil) -> Table {
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

        var qry = msgs
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
            qry = qry.limit(limit, offset: offset)
        } else {
            qry = qry.limit(limit)
        }

        // TODO: this is a very handy query but also used in a lot of places
        // maybe should be split apart into a wrapper like filterOnlyFollowedPeople which is just func(Table) -> Table
        if onlyRoots {
            qry = qry.filter(colIsRoot == true)   // only thread-starting posts (no replies)
        }
        return qry
    }

    private func filterOnlyFollowedPeople(qry: Table) throws -> Table {
        let contacts = Table(ViewDatabaseTableNames.contacts.rawValue)
        let colAuthorID = Expression<Int64>("author_id")
        let colContactID = Expression<Int64>("contact_id")
        let colContactState = Expression<Int>("state")

        // get the list of people that the active user follows
        let myFollowsQry = contacts
            .select(colContactID)
            .filter(colAuthorID == self.currentUserID)
            .filter(colContactState == 1)
        var myFollows: [Int64] = [self.currentUserID] // and from self as well
        for row in try connection.prepare(myFollowsQry) {
            myFollows.append(row[colContactID])
        }
        return qry.filter(myFollows.contains(colAuthorID))    // authored by one of our follows
    }

    private func filterNotFollowingPeople(qry: Table) throws -> Table {
        let contacts = Table(ViewDatabaseTableNames.contacts.rawValue)
        let colAuthorID = Expression<Int64>("author_id")
        let colContactID = Expression<Int64>("contact_id")
        let colContactState = Expression<Int>("state")

        // get the list of people that the active user follows
        let myFollowsQry = contacts
            .select(colContactID)
            .filter(colAuthorID == self.currentUserID)
            .filter(colContactState == 1)
        var myFollows: [Int64] = [self.currentUserID] // and from self as well
        for row in try connection.prepare(myFollowsQry) {
            myFollows.append(row[colContactID])
        }
        return qry.filter(!(myFollows.contains(colAuthorID)))    // authored by one of our follows
    }

    private func mapQueryToKeyValue(qry: Table) throws -> [KeyValue] {
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

        // TODO: add switch over type (to support contact, vote, gathering, etc..)

        return try connection.prepare(qry).compactMap { row in
            // tried 'return try row.decode()'
            // but failed - see https://github.com/VerseApp/ios/issues/29

            let msgID = try row.get(colMessageID)

            let msgKey = try row.get(colKey)
            let msgAuthor = try row.get(colAuthor)

            var c: Content

            let type = try row.get(msgs[colMsgType])

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
                    let cc = Contact(contact: msgAuthor, following: following)

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
                name: try row.get(abouts[colName]),
                description: try row.get(colDescr),
                imageLink: try row.get(colImage)
            )
            keyValue.metadata.isPrivate = try row.get(colDecrypted)
            return keyValue
        }
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

    private func addNumberOfPeopleReplied(msgs: [KeyValue]) throws -> KeyValues {
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

        var r: KeyValues = []
        for (index, _) in msgs.enumerated() {
            var msg = msgs[index]
            let msgID = try self.msgID(of: msg.key)

            let replies = tangles
                .select(colAuthorID.distinct, colAuthor, colName, colDescr, colImage)
                .join(messages, on: messages[colMessageID] == tangles[colMessageRef])
                .join(authors, on: messages[colAuthorID] == authors[colID])
                .join(abouts, on: authors[colID] == abouts[colAboutID])
                .filter(colMsgType == ContentType.post.rawValue || colMsgType == ContentType.vote.rawValue)
                .filter(colRoot == msgID)

            let count = try connection.scalar(replies.count)

            var abouts: [About] = []
            for row in try connection.prepare(replies.limit(3, offset: 0)) {
                let about = About(about: row[colAuthor],
                                  name: row[colName],
                                  description: row[colDescr],
                                  imageLink: row[colImage])
                abouts += [about]
            }

            msg.metadata.replies.count = count
            msg.metadata.replies.abouts = abouts
            r.append(msg)
        }
        return r
    }

    private func msgID(of key: MessageIdentifier, make: Bool = false) throws -> Int64 {
        let msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)
        let colID = Expression<Int64>("id")
        let colKey = Expression<MessageIdentifier>("key")
        let colHashedKey = Expression<String>("hashed")

        if let msgKeysRow = try connection.pluck(msgKeys.filter(colKey == key)) {
            return msgKeysRow[colID]
        }

        guard make else { throw ViewDatabaseError.unknownMessage(key) }

        return try connection.run(msgKeys.insert(
            colKey <- key,
            colHashedKey <- key.sha256hash
        ))
    }
}
