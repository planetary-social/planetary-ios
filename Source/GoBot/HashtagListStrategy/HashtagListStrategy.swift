//
//  HashtagListStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 3/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// Defines a family of functions needed for fetching a list of hashtags from the database
///
/// This strategy supports having a family of algorithms that implement fetching
/// a list of hashtags in different and unique ways, and making them interchangeable.
protocol HashtagListStrategy {
    /// Returns the hashtags in the list
    /// - parameter connection: the database connection needed to run queries in the database
    /// - parameter userId: the ID of the user for which the list will be calculated from
    func fetchHashtags(connection: Connection, userId: Int64) throws -> [Hashtag]
}
