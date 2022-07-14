//
//  ContentVote+ViewDatabase.swift
//  Planetary
//
//  Created by Martin Dutra on 14/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension ContentVote {

    init(row: Row, db: ViewDatabase) throws {
        let lnkID = try row.get(db.colLinkID)
        let lnkKey = try db.msgKey(id: lnkID)
        let rootID = try row.get(db.colRoot)
        let rootKey = try db.msgKey(id: rootID)
        self.init(
            link: lnkKey,
            value: try row.get(db.colValue),
            expression: try row.get(db.colExpression),
            root: rootKey,
            branches: [] // TODO: branches for root
        )
    }
}
