//
//  FeedStrategyBuilder.swift
//  Planetary
//
//  Created by Martin Dutra on 30/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// 
class FeedStrategyBuilder {
    func buildHomeFeedStrategy() -> FeedStrategy {
        return PostsAndContactsAlgorithm()
    }

    func buildDiscoverFeedStrategy() -> FeedStrategy {
        return PostsAlgorithm(wantPrivate: false, onlyFollowed: false)
    }
}
