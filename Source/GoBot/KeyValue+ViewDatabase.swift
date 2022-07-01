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
    init?(row: Row, database: ViewDatabase, useNamespacedTables: Bool = false) throws {
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
            
            let p = Post(
                blobs: try db.loadBlobs(for: msgID),
                mentions: try db.loadMentions(for: msgID),
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
        keyValue.metadata.isPrivate = try row.get(db.colDecrypted)
        self = keyValue
    }
}
