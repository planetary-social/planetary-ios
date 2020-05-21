//
//  NullCrashReporting.swift
//  Planetary
//
//  Created by Martin Dutra on 4/1/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A null implementation of the CrashReportingService protocol suitable
/// for use with unit or API test targets.

class NullCrashReporting: CrashReportingService {
    
    func identify(about: About?, network: NetworkKey) { }
    
    func forget() { }
    
    func crash() { }
    
    func record(_ message: String) { }
    
    func reportIfNeeded(error: Error?) { }

    func reportIfNeeded(error: Error?, metadata: [AnyHashable: Any]) { }
    
}
