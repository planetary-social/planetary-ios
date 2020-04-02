//
//  Onboarding+Repair.swift
//  Planetary
//
//  Created by Christoph on 11/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Onboarding {

    static func repair2019113() {

        // ensure being logged in
        guard let identity = Bots.current.identity else {
            Log.unexpected(.missingValue, "\(#function): Cannot repair onboarding without being logged in")
            return
        }

        // only run on our network
        guard AppConfiguration.current?.network == NetworkKey.planetary else { return }

        guard Bots.current.statistics.repo.feedCount != -1 else {
            Log.unexpected(.botError, "\(#function): warning: repo stats not ready yet")
            return
        }

        // check feedCount indicates that there are pubs following
        guard Bots.current.statistics.repo.feedCount < 2 else { return }
        Log.info("\(#function): feedCount < 2 so likely this identity is not being followed by pubs")

        // request follow back
        PubAPI().invitePubsToFollow(identity) {
            success, error in
            CrashReporting.shared.reportIfNeeded(error: error)
            if success {
                Log.info("\(#function): successfully completed follow back request")
            } else {
                Log.info("\(#function): failed follow back request")
                Log.optional(error)
            }
        }

        // analytics
        Analytics.track(event: .did,
                        element: .app,
                        name: AnalyticsEnums.Name.repair.rawValue,
                        param: "function",
                        value: #function)
    }
}
