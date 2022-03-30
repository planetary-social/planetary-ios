//
//  PushAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct PushAPI {
    
    static var shared: PushAPIService = {
        // We don't want to spam the push API when running tests
        #if UNIT_TESTS
        return NullPushAPI()
        #else
        if CommandLine.arguments.contains("mock-push-api") {
            return NullPushAPI()
        } else {
            return VersePushAPI()
        }
        #endif
    }()
}
