//
//  About+ViewDatabase.swift
//  Planetary
//
//  Created by Matthew Lorentz on 9/1/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension About {
    init(row: Row, db: ViewDatabase) throws {
        let abouts = db.abouts
        let aboutID = try db.author(from: try row.get(abouts[db.colAboutID]))
        self.init(
            about: aboutID,
            name: try row.get(abouts[db.colName]),
            description: try row.get(abouts[db.colDescr]),
            imageLink: try row.get(abouts[db.colImage]),
            publicWebHosting: try row.get(abouts[db.colPublicWebHosting])
        )
    }
}
