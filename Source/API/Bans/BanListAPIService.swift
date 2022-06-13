//
//  BanListAPIService.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias BanList = [String]

/// An object that fetches a list of banned content from an API.
protocol BanListAPIService {

    // retreives the full list, no pagination
    func retreiveBanList(for identifier: FeedIdentifier) async throws -> BanList
}
