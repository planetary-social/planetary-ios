//
//  PubAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct PubAPI {
    
    static var shared: PubAPIService = {
        // We don't want to spam the push API when running unit tests
        #if UNIT_TESTS
        return NullPubAPI()
        #else
        if CommandLine.arguments.contains("mock-pub-api") {
            return NullPubAPI()
        } else {
            return VersePubAPI()
        }
        #endif
    }()
}
