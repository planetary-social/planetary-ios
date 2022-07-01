//
//  RecentStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// Defines a family of functions needed for fetching a feed of keyvalues from the database, i.e., the Home Feed
///
/// This strategy supports having a family of algorithms that implement fetching
/// a feed in different and unique ways (one could fetch just posts, another one
/// could fetch posts and follows, and so on), and making them interchangeable.
protocol FeedStrategy: NSObjectProtocol, NSCoding {
    /// Returns the total number of items in the feed
    /// - parameter connection: the database connection needed to run queries in the database
    /// - parameter userId: the ID of the user for which the feed will be calculated from
    ///
    /// It must be the same number of items that fetchKeyValues and fetchKeys returns.
    func countNumberOfKeys(connection: Connection, userId: Int64) throws -> Int

    /// Returns the items (key values) in the feed
    /// - parameter connection: the database connection needed to run queries in the database
    /// - parameter userId: the ID of the user for which the feed will be calculated from
    /// - parameter limit: the number of items that should be returned
    /// - parameter offset: the offset, offset=10 will return the 10th item onwards,
    /// offset=nil will return the first item onwards
    func fetchKeyValues(connection: Connection, userId: Int64, limit: Int, offset: Int?) throws -> [KeyValue]

    /// Returns the total number of items in the feed since a specific message
    /// - parameter connection: the database connection needed to run queries in the database
    /// - parameter userId: the ID of the user for which the feed will be calculated from
    /// - parameter message: the offset
    func countNumberOfKeys(connection: Connection, userId: Int64, since message: MessageIdentifier) throws -> Int
}
