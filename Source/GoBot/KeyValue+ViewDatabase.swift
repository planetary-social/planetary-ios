//
//  KeyValue+ViewDatabase.swift
//  Planetary
//
//  Created by Matthew Lorentz on 6/30/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension KeyValue {
    
    /// Creates a KeyValue from a database row. Copied from ViewDatabase.swift, still very messy. It's unclear what
    /// columns are required for this function to succeed, but in general I think it's messages joined with message keys
    /// joined with the post type (i.e posts) joined with authors. See `ViewDatabase.fillMessages` for a working
    /// example.
    /// - Parameters:
    ///   - row: The SQLite row that should be used to make the KeyValue.
    ///   - database: A database instance that will be used to fetch supplementary information.
    ///   - useNamespacedTables: A boolean that tells the initializer to include table names before some common column
    ///     names that appear in multiple tables like `name`.
    ///   - hasMentionColumns: A flag that lets the parser know whether the row includes the columns `hasblobs`,
    ///     `has_feed_mentions`, `has_message_mentions`. These columns are an optimization to speed up the loading of
    ///     Posts.
    ///   - hasReplies: A flag that lets the parse know whether the row `replies_count` and `replies` columns as an
    ///     optimization for loading post replies.
    init?(
        row: Row,
        database: ViewDatabase,
        useNamespacedTables: Bool = false,
        hasMentionColumns: Bool = true,
        hasReplies: Bool = true
    ) throws {
        // tried 'return try row.decode()'
        // but failed - see https://github.com/VerseApp/ios/issues/29
        
        let db = database
        let colRootMaybe = Expression<Int64?>("root")

        let msgID = try row.get(db.colMessageID)
        
        let msgKey = try row.get(db.colKey)
        let msgAuthor = try row.get(db.colAuthor)

        var c: Content
           
        let type = try row.get(db.colMsgType)
        
        switch type {
        case ContentType.post.rawValue:
            
            var rootKey: Identifier?
            if let rootID = try row.get(colRootMaybe) {
                rootKey = try db.msgKey(id: rootID)
            }
            
            var blobs: Blobs
            var mentions: [Mention]
            if hasMentionColumns {
                let hasBlobs = try row.get(Expression<Bool>("has_blobs"))
                blobs = hasBlobs ? try db.loadBlobs(for: msgID) : []
                
                mentions = [Mention]()
                let hasFeedMentions = try row.get(Expression<Bool>("has_feed_mentions"))
                if hasFeedMentions {
                    mentions.append(contentsOf: try db.loadFeedMentions(for: msgID))
                }
                let hasMessageMentions = try row.get(Expression<Bool>("has_message_mentions"))
                if hasMessageMentions {
                    mentions.append(contentsOf: try db.loadMessageMentions(for: msgID))
                }
            } else {
                blobs = try db.loadBlobs(for: msgID)
                mentions = try db.loadMentions(for: msgID)
            }
            
            let p = Post(
                blobs: blobs,
                mentions: mentions,
                root: rootKey,
                text: try row.get(db.colText)
            )
            
            c = Content(from: p)
            
        case ContentType.vote.rawValue:
            
            let lnkID = try row.get(db.colLinkID)
            let lnkKey = try db.msgKey(id: lnkID)
            
            let rootID = try row.get(db.colRoot)
            let rootKey = try db.msgKey(id: rootID)
            
            let cv = ContentVote(
                link: lnkKey,
                value: try row.get(db.colValue),
                expression: try row.get(db.colExpression),
                root: rootKey,
                branches: [] // TODO: branches for root
            )
            
            c = Content(from: cv)
        case ContentType.contact.rawValue:
            if let state = try? row.get(db.colContactState) {
                let identifier = try row.get(Expression<Identifier>("contact_identifier"))
                
                if state == 1 {
                    c = Content(from: Contact(contact: identifier, following: true))
                } else if state == -1 {
                    c = Content(from: Contact(contact: identifier, blocking: true))
                } else {
                    c = Content(from: Contact(contact: identifier, following: false))
                }
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
            sequence: try row.get(db.colSequence),
            signature: "verified_by_go-ssb",
            timestamp: try row.get(db.colClaimedAt)
        )
        var keyValue = KeyValue(
            key: msgKey,
            value: v,
            timestamp: try row.get(db.colReceivedAt),
            offChain: try row.get(db.colOffChain)
        )
        let aboutName = useNamespacedTables ? db.abouts[db.colName] : db.colName
        keyValue.metadata.author.about = About(
            about: msgAuthor,
            name: try row.get(aboutName),
            description: try row.get(db.colDescr),
            imageLink: try row.get(db.colImage)
        )
        if hasReplies {
            let numberOfReplies = try row.get(Expression<Int>("replies_count"))
            let replies = try row.get(Expression<String?>("replies"))
            let abouts = replies?.split(separator: ";").map { About(about: String($0)) } ?? []
            keyValue.metadata.replies.count = numberOfReplies
            keyValue.metadata.replies.abouts = abouts
        }
        keyValue.metadata.isPrivate = try row.get(db.colDecrypted)
        self = keyValue
    }
}
