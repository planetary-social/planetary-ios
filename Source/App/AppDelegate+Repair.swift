//
//  AppDelegate+Repair.swift
//  Planetary
//
//  Created by Christoph on 1/16/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Analytics

extension AppDelegate {

    /// IMPORTANT!
    /// Repairs all the known Keychain values by re-applying them, which will update the
    /// accessibility to allow use while backgrounded.
    /// This MUST be called as soon as possible in `AppDelegate.application(didFinishLaunchingWithOptions:)`
    /// before any use of the Keychain, otherwise the app may not behave as expected.  However, since it is
    /// tracked in analytics, those must be configured before this call.
    func repair20200116() {

        // repair configurations
        if let configuration = AppConfiguration.current { configuration.apply() }
        let configurations = AppConfigurations.current
        if configurations.count > 0 { AppConfigurations.current.save() }

        // repair onboarding status' for all identities
        for configuration in configurations {
            guard let identity = configuration.identity else { continue }
            let status = Onboarding.status(for: identity)
            Onboarding.set(status: status, for: identity)
        }

        Analytics.shared.trackDidRepair(function: #function)
    }
}
