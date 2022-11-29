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
    var followers: [Identity]

    var someFollowersAvatars: [ImageMetadata?]

    /// The total number of follows of an identity
    var follows: [Identity]

    var someFollowsAvatars: [ImageMetadata?]

    /// The total number of blocks of an identity
    var blocks: [Identity]

    var someBlocksAvatars: [ImageMetadata?]

    /// The total number of pub servers an identity joined
    var pubServers: [Identity]

    var somePubServersAvatars: [ImageMetadata?]

    static var zero: ExtendedSocialStats {
        ExtendedSocialStats(
            followers: [],
            someFollowersAvatars: [],
            follows: [],
            someFollowsAvatars: [],
            blocks: [],
            someBlocksAvatars: [],
            pubServers: [],
            somePubServersAvatars: []
        )
    }
}
