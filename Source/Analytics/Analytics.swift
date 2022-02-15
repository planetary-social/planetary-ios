//
//  Analytics.swift
//  Planetary
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Analytics {
    
    static var shared: AnalyticsService = {
        #if DEBUG
        return NullAnalytics()
        #else
        if CommandLine.arguments.contains("mock-analytics") {
            return NullAnalytics()
        } else {
            return PostHogAnalytics()
        }
        #endif
    }()
    
}
