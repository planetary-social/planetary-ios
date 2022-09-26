//
//  MessageValue.swift
//  FBTT
//
//  Created by Christoph on 4/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// The `value` key in a Scuttlebutt `Message`. This container holds the
/// majority of the message data, while the top level `Message` struct holds
/// just the message key. This object is here for Codable support but in
/// general you shoudl access the properties here through their aliases
/// on `Message`.
struct MessageValue: Codable {
    enum CodingKeys: String, CodingKey {
        case author
        case content
        case hash
        case previous
        case sequence
        case signature
        case claimedTimestamp = "timestamp"
    }
    
    let author: FeedIdentifier
    let content: Content
    let hash: String
    let previous: MessageIdentifier?   // TODO? only if seq == 1 but external sbot handles this currently
    let sequence: Int
    let signature: Identifier
    
    /// The time that the poster claims to have posted this message. Should not be trusted.
    /// Note that this is time in milliseconds, not seconds.
    let claimedTimestamp: Float64
}
