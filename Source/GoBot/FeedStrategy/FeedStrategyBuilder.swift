//
//  FeedStrategyBuilder.swift
//  Planetary
//
//  Created by Martin Dutra on 30/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

class FeedStrategyBuilder {
    func buildHomeFeedStrategy(connection: Connection, currentUserID: Int64) -> FeedStrategy {
        return PostsAndContactsStrategy(
            connection: connection,
            currentUserID: currentUserID
        )
    }

    func buildDiscoverFeedStrategy(connection: Connection, currentUserID: Int64) -> FeedStrategy {
        return CurrentPostsStrategy(
            connection: connection,
            currentUserID: currentUserID,
            wantPrivate: false,
            onlyFollowed: true
        )
    }
}
