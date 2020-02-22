//
//  Cache.swift
//  FBTT
//
//  Created by Christoph on 6/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol Cache {

    var count: Int { get }
    var estimatedBytes: Int { get }

    func bytes(for item: Any) -> Int
    func item(for key: String) -> Any?

    func purge()
    func invalidate()
    func invalidateItem(for key: String)
}
