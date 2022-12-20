//
//  RoomAliasAnnouncement+ViewDatabase.swift
//  Planetary
//
//  Created by Chad Sarles on 11/22/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension RoomAlias {
    init(row: Row, db: ViewDatabase) throws {
        
        let rowAliasURLString = try row.get(db.colAliasURL)
        
        guard let aliasURL = URL(string: rowAliasURLString) else {
            throw ViewDatabaseError.invalidAliasURL(rowAliasURLString)
        }
        let id = try row.get(db.colID)
        
        let roomID: Int64? = try row.get(db.colRoomID)
        
        self.init(
            id: id,
            aliasURL: aliasURL,
            roomID: roomID,
            authorID: try row.get(db.colAuthorID)
        )
    }
}
