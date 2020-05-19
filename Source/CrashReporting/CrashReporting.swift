//
//  CrashReporting.swift
//  Planetary
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct CrashReporting {
    
    static var shared: CrashReportingService = {
        #if DEBUG
        return NullCrashReporting()
        #else
        if CommandLine.arguments.contains("mock-crash-reporting") {
            return NullCrashReporting()
        } else {
            return BugsnagCrashReporting()
        }
        #endif
    }()
    
}
