//
//  AppController+ConstellationCheck.swift
//  Planetary
//
//  Created by Martin Dutra on 8/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppController {
    
    func runConstellationCheck() {
        Bots.current.pubs { [weak self] (pubs, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            let stars = Set(Environment.Constellation.stars)
            
            let connectedStars = stars.filter { star in
                pubs.contains { (pub) -> Bool in
                    pub.address.key == star.feed
                }
            }
            
            let numberOfMissingStars = 3 - connectedStars.count
            if numberOfMissingStars > 0 {
                let notConnectedStars = stars.subtracting(connectedStars)
                let missingStars = notConnectedStars.randomSample(UInt(numberOfMissingStars))
                let redeemInviteOperations = missingStars.map{ RedeemInviteOperation(token: $0.invite) }
                self?.operationQueue.addOperations(redeemInviteOperations, waitUntilFinished: false)
            }
        }
    }
}
