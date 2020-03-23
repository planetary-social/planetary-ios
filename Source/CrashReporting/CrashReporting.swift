//
//  CrashReporting.swift
//  Planetary
//
//  Created by Martin Dutra on 3/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Bugsnag

class CrashReporting {
    
    private static var configured: Bool = false
    
    static func configure() {
        guard let token = Environment.Bugsnag.token else {
            configured = false
            return
        }
        Bugsnag.start(withApiKey: token)
        configured = true
    }
    
    static func crash() {
        guard configured else {
            return
        }
        Bugsnag.notifyError(NSError(domain: "com.planetary.social", code: 408, userInfo: nil))
    }
    
}
