//
//  FollowStats.swift
//  Planetary
//
//  Created by Martin Dutra on 9/5/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A model representing the number of followers and follows of an identity
///
/// Ideally, the number of followers and follows are presented in the UI at the same time
/// and thus should be fetched at the same time from the database. This model appears
/// to encapsulate this requirement.
struct FollowStats {

    /// The total number of followers of an identity
    var numberOfFollowers: Int

    /// The total number of followes of an identity
    var numberOfFollows: Int
}
