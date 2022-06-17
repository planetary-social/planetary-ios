//
//  BanListAPI.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A singleton for the `BanListAPIService` that chooses different services based on the environment.
enum BanListAPI {
    
    static var shared: BanListAPIService = {
        // We don't want to spam the push API when running unit tests
        #if UNIT_TESTS
        return NullBanListAPI()
        #else
        if CommandLine.arguments.contains("mock-pub-api") {
            return NullBanListAPI()
        } else {
            return BearerBanListAPI()
        }
        #endif
    }()
}
