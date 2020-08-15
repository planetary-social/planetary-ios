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
        
        
        Bots.current.knownPubs { (knownPubs, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
//            let stars = Set(Environment.Constellation.stars)
//            
//            let connectedStars = stars.filter { star in
//                knownPubs.contains { (knownPub) -> Bool in
//                    knownPub.ForFeed == star.feed
//                }
//            }
//            
//            let numberOfMissingStars = 3 - connectedStars.count
//            if numberOfMissingStars > 0 {
//                let notConnectedStars = stars.subtracting(connectedStars)
//                let missingStars = notConnectedStars.randomSample(UInt(numberOfMissingStars))
//                let redeemInviteOperations = missingStars.map{ RedeemInviteOperation(token: $0.invite) }
//                
//            }
            
        }

        let operation = StatisticsOperation()
        operation.completionBlock = {
            switch operation.result {
            case .success(let stats):
                guard stats.repo.feedCount != -1 else {
                    Log.unexpected(.botError, "\(#function): warning: repo stats not ready yet")
                    return
                }

                // check feedCount indicates that there are pubs following
                guard stats.repo.feedCount < 2 else {
                    return
                }

                Log.info("\(#function): feedCount < 2 so likely this identity is not being followed by pubs")

                // request follow back
                PubAPI.shared.invitePubsToFollow(identity) {
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
                Analytics.shared.track(event: .did,
                                element: .app,
                                name: AnalyticsEnums.Name.repair.rawValue,
                                param: "function",
                                value: #function)
            case .failure(let error):
                CrashReporting.shared.reportIfNeeded(error: error)
            }
        }

        let operationQueue = OperationQueue()
        operationQueue.addOperations([operation], waitUntilFinished: true)
    }
}
