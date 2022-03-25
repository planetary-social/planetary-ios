//
//  Support.swift
//  Planetary
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Support {
    
    static var shared: SupportService = {
        #if DEBUG
        return NullSupport()
        #else
        if CommandLine.arguments.contains("mock-support") {
            return NullSupport()
        } else {
            return ZendeskSupport()
        }
        #endif
    }()
}
