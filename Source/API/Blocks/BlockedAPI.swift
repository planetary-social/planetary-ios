//
//  BlockedAPI.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct BlockedAPI {
    
    static var shared: BlockedAPIService = {
        // We don't want to spam the push API when running unit tests
        #if UNIT_TESTS
        return NullBlockedAPI()
        #else
        if CommandLine.arguments.contains("mock-pub-api") {
            return NullBlockedAPI()
        } else {
            return PlanetaryBearerBlockedAPI()
        }
        #endif
    }()
}
