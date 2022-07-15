//
//  Contact+ViewDatabase.swift
//  Planetary
//
//  Created by Martin Dutra on 14/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension Contact {
    init?(row: Row, db: ViewDatabase) throws {
        if let state = try? row.get(db.colContactState) {
            let identifier = try row.get(Expression<Identifier>("contact_identifier"))
            if state == 1 {
                self.init(contact: identifier, following: true)
            } else if state == -1 {
                self.init(contact: identifier, blocking: true)
            } else {
                self.init(contact: identifier, following: false)
            }
        } else {
            return nil
        }
    }
}
