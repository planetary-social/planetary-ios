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
    func buildHomeFeedStrategy() -> FeedStrategy {
        return PostsAndContactsStrategy()
    }

    func buildDiscoverFeedStrategy() -> FeedStrategy {
        return CurrentPostsStrategy(wantPrivate: false, onlyFollowed: false)
    }
}
