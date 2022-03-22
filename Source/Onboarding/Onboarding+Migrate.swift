//
//  Onboarding+Migrate.swift
//  FBTT
//
//  Created by Christoph on 5/31/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import CrashReporting

extension Onboarding {

    // TODO https://app.asana.com/0/914798787098068/1125341035741855/f
    static func fixIdentityFollowBack() {
        guard UserDefaults.standard.fixIdentityFollowBack else { return }
        guard let identity = AppConfiguration.current?.identity else { return }
        Log.info("\(#function)")
        Onboarding.invitePubsToFollow(identity) {
            success, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }
}

fileprivate extension UserDefaults {

    // Convenience property to limit the above `fixIdentityFollowBack` to
    // only be called once.  This is a write-on-read property meaning
    // calling once will return true, and calling subsequent times will
    // return false without having to set the property.
    var fixIdentityFollowBack: Bool {
        if self.object(forKey: #function) == nil {
            self.set(false, forKey: #function)
            return true
        } else {
            return false
        }
    }
}
