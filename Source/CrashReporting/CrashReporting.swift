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
    
    static let shared = CrashReporting()
    
    private var configured: Bool = false
    
    var about: About? {
        didSet {
            if let about = about, configured {
                Bugsnag.configuration()?.setUser(about.identity, withName: about.name, andEmail: nil)
            }
        }
    }
    
    func configure() {
        guard let token = Environment.Bugsnag.token else {
            configured = false
            return
        }
        Log.info("Configuring Bugsnag...")
        Bugsnag.start(withApiKey: token)
        configured = true
    }
    
    func crash() {
        guard configured else {
            return
        }
        Bugsnag.notifyError(NSError(domain: "com.planetary.social", code: 408, userInfo: nil))
    }
    
    func record(_ message: String) {
        guard configured else {
            return
        }
        Bugsnag.leaveBreadcrumb(withMessage: message)
    }
    
    func reportIfNeeded(error: Error?) {
        guard configured, let error = error else {
            return
        }
        Bugsnag.notifyError(error)
    }
    
}
