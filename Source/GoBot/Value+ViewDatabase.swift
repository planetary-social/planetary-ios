//
//  Value+ViewDatabase.swift
//  Planetary
//
//  Created by Martin Dutra on 14/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension Value {
    init?(row: Row, db: ViewDatabase, hasMentionColumns: Bool) throws {
        var content: Content
        let type = try row.get(db.colMsgType)
        switch type {
        case ContentType.post.rawValue:
            content = Content(from: try Post(row: row, db: db, hasMentionColumns: hasMentionColumns))
        case ContentType.vote.rawValue:
            content = Content(from: try ContentVote(row: row, db: db))
        case ContentType.contact.rawValue:
            guard let contact = try Contact(row: row, db: db) else {
                // Contacts stores only the latest message
                // So, an old follow that was later unfollowed won't appear here.
                return nil
            }
            content = Content(from: contact)
        default:
            throw ViewDatabaseError.unexpectedContentType(type)
        }
        self.init(
            author: try row.get(db.colAuthor),
            content: content,
            hash: "sha256",
            previous: nil,
            sequence: try row.get(db.colSequence),
            signature: "verified_by_go-ssb",
            timestamp: try row.get(db.colClaimedAt)
        )
    }
}
