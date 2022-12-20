//
//  MessageValue+ViewDatabase.swift
//  Planetary
//
//  Created by Martin Dutra on 14/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension MessageValue {
    init?(row: Row, db: ViewDatabase, useNamespacedTables: Bool = false, hasMentionColumns: Bool) throws {
        var content: Content
        let type = try row.get(db.colMsgType)
        switch ContentType(rawValue: type) {
        case .post:
            content = Content(from: try Post(row: row, db: db, hasMentionColumns: hasMentionColumns))
        case .vote:
            content = Content(from: try ContentVote(row: row, db: db))
        case .contact:
            guard let contact = try Contact(row: row, db: db, useNamespacedTables: useNamespacedTables) else {
                // Contacts stores only the latest message
                // So, an old follow that was later unfollowed won't appear here.
                return nil
            }
            content = Content(from: contact)
        case .about:
            content = Content(from: try About(row: row, db: db))
        case .pub:
            content = Content(from: try Pub(row: row, db: db))
        case .dropContentRequest, .address, .unknown, .unsupported, .roomAliasAnnouncement, .none:
            throw ViewDatabaseError.unexpectedContentType(type)
        }
        
        var author: Identity
        if useNamespacedTables {
            author = try row.get(db.authors[db.colAuthor])
        } else {
            author = try row.get(db.colAuthor)
        }
        
        self.init(
            author: author,
            content: content,
            hash: "sha256",
            previous: nil,
            sequence: try row.get(db.colSequence),
            signature: "verified_by_go-ssb",
            claimedTimestamp: try row.get(db.colClaimedAt)
        )
    }
}
