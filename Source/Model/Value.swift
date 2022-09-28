//
//  Value.swift
//  FBTT
//
//  Created by Christoph on 4/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Value: Codable {
    let author: Identity
    let content: Content
    let hash: String
    let previous: Identifier?   // TODO? only if seq == 1 but external sbot handles this currently
    let sequence: Int
    let signature: Identifier
    
    /// The time that the poster claims to have posted this message. Should not be trusted, unless it's from someone
    /// we follow/trust. Note that this is time in milliseconds, not seconds.
    let timestamp: Float64
}
