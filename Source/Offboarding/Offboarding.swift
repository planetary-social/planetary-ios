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

    static func offboard() async throws {
        guard let identity = Bots.current.identity else { throw OffboardingError.mustBeLoggedIn }
        guard let configuration = AppConfiguration.current else { throw OffboardingError.invalidConfiguration }
        guard configuration.identity == identity else { throw OffboardingError.invalidIdentity }

        Analytics.shared.trackOffboardingStart()

        // log out
        // errors not allowed
        do {
            try await Bots.current.logout()
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            throw OffboardingError.botError(error)
        }
            
        // remove configuration
        configuration.unapply()
        AppConfigurations.delete(configuration)
        
        // done
        Analytics.shared.trackOffboardingEnd()
        Analytics.shared.forget()
    }
}
