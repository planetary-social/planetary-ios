//
//  JoinPlanetarySystemOperation.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// Joins the Planetary System pubs if the user has opted in.
class JoinPlanetarySystemOperation: AsynchronousOperation {
    
    private var appConfiguration: AppConfiguration
    
    private var operationQueue: OperationQueue
    
    /// Minimum number of Planetary's pubs that should be followng the user for them to be considered in the system.
    static let minNumberOfStars = 3
    
    let userDefaults = UserDefaults.standard
    
    init(appConfiguration: AppConfiguration, operationQueue: OperationQueue) {
        self.appConfiguration = appConfiguration
        self.operationQueue = operationQueue
    }
    
    override func main() {
        guard let bot = appConfiguration.bot else {
            Log.info("JoinPlanetarySystemOperation was given an AppConfiguration with no Bot.")
            self.finish()
            return
        }
        
        guard self.userDefaults.bool(forKey: "prevent_feed_from_forks") else {
            Log.info(
                "JoinPlanetarySystemOperation refusing to join Planetary system pubs because forked feed " +
                " protection is turned off."
            )
            self.finish()
            return
        }
        
        guard appConfiguration.joinedPlanetarySystem else {
            self.finish()
            return
        }
        
        Task {
            do {
                let allJoinedPubs = try await bot.joinedPubs()
                let systemPubs = Set(AppConfiguration.current?.systemPubs ?? [])
                let joinedSystemPubs = systemPubs.filter { star in
                    allJoinedPubs.contains { (pub) -> Bool in
                        pub.address.key == star.feed
                    }
                }
            
                let numberOfMissingStars = Self.minNumberOfStars - joinedSystemPubs.count
                if numberOfMissingStars > 0 {
                    Log.debug("User needs to be followed by \(numberOfMissingStars) to be part of the Planetary System")
                    
                    // Let's take a random set of stars to reach the minimum and create Redeem Invite
                    // operations
                    let missingStars = systemPubs.subtracting(joinedSystemPubs)
                    guard !missingStars.isEmpty else {
                        Log.debug("Not enough system pubs to reach minimum")
                        self.finish()
                        return
                    }
                    let randomSampleOfStars = missingStars.randomSample(UInt(numberOfMissingStars))
                    var redeemInviteOperations = [RedeemInviteOperation]()
                    redeemInviteOperations = randomSampleOfStars.map {
                        RedeemInviteOperation(star: $0, shouldFollow: false)
                    }
                    
                    // Sync with stars after following
                    let peerPool = randomSampleOfStars.compactMap { $0.toPeer().multiserverAddress }
                    
                    let syncOperation = SyncOperation(peerPool: peerPool)
                    redeemInviteOperations.forEach { syncOperation.addDependency($0) }
                    
                    let operations = redeemInviteOperations + [syncOperation]
                    self.operationQueue.addOperations(operations, waitUntilFinished: true)
                }
            } catch {
                Log.optional(error)
            }
                
            self.finish()
        }
    }
}
