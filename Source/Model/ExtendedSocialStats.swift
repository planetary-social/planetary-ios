//
//  ExtendedSocialStats.swift
//  Planetary
//
//  Created by Martin Dutra on 30/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A model representing the number of followers and follows of an identity
///
/// Ideally, the number of followers and follows are presented in the UI at the same time
/// and thus should be fetched at the same time from the database. This model appears
/// to encapsulate this requirement.
struct ExtendedSocialStats {
    /// The total number of followers of an identity
    var numberOfFollowers: Int

    var followers: [ImageMetadata?]

    /// The total number of follows of an identity
    var numberOfFollows: Int

    var follows: [ImageMetadata?]

    /// The total number of blocks of an identity
    var numberOfBlocks: Int

    var blocks: [ImageMetadata?]

    /// The total number of pub servers an identity joined
    var numberOfPubServers: Int

    var pubServers: [ImageMetadata?]

    static var zero: ExtendedSocialStats {
        ExtendedSocialStats(
            numberOfFollowers: 0,
            followers: [],
            numberOfFollows: 0,
            follows: [],
            numberOfBlocks: 0,
            blocks: [],
            numberOfPubServers: 0,
            pubServers: []
        )
    }
}
