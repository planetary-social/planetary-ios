//
//  Pub+ViewDatabase.swift
//  Planetary
//
//  Created by Matthew Lorentz on 9/1/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension Pub {
    init(row: Row, db: ViewDatabase) throws {
        let host = try row.get(db.colHost)
        let port = try row.get(db.colPort)
        let key: Identifier = try row.get(db.pubs[db.colKey])
        
        self.init(
            type: .pub,
            address: PubAddress(
                key: key,
                host: host,
                port: UInt(port)
            )
        )
    }
}
