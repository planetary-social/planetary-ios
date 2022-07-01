//
//  Offboarding.swift
//  Planetary
//
//  Created by Christoph on 12/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Analytics
import CrashReporting

enum OffboardingError: Error {
    case apiError(Error)
    case botError(Error)
    case invalidConfiguration
    case invalidIdentity
    case mustBeLoggedIn
    case other(Error?)
}

enum Offboarding {

    typealias Completion = ((OffboardingError?) -> Void)

    static func offboard(completion: @escaping Completion) {
        guard let identity = Bots.current.identity else { completion(.mustBeLoggedIn); return }
        guard let configuration = AppConfiguration.current else { completion(.invalidConfiguration) ; return }
        guard configuration.identity == identity else { completion(.invalidIdentity); return }

        Analytics.shared.trackOffboardingStart()

        // log out
        // errors not allowed
        Bots.current.logout { error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            if let error = error { completion(.botError(error)); return }
            
            // remove configuration
            configuration.unapply()
            AppConfigurations.delete(configuration)
            
            // done
            Analytics.shared.trackOffboardingEnd()
            Analytics.shared.forget()
            
            completion(nil)
        }
    }
}
