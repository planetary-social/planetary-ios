//
//  NullBlocksAPI.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

/// A service that always returns an empty ban list. Used to avoid hammering our real service with CI builds etc.
class NullBanListAPI: BanListAPIService {

    func retreiveBanList(for identifier: FeedIdentifier) async throws -> BanList {
        []
    }
}
