//
//  Post+ViewDatabase.swift
//  Planetary
//
//  Created by Martin Dutra on 14/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension Post {
    convenience init(row: Row, db: ViewDatabase, hasMentionColumns: Bool) throws {
        let msgID = try row.get(db.colMessageID)

        var rootKey: Identifier?
        if let rootID = try row.get(Expression<Int64?>("root")) {
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

        self.init(
            blobs: blobs,
            mentions: mentions,
            root: rootKey,
            text: try row.get(db.colText)
        )
    }
}
