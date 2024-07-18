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
    
    /// A queue we will use to wait on multiple JoinPlanetarySystemOperations.
    private var internalQueue: OperationQueue
    
    /// Minimum number of Planetary's pubs that should be followng the user for them to be considered in the system.
    static let minNumberOfStars = 2
    
    let userDefaults = UserDefaults.standard
    
    init(appConfiguration: AppConfiguration) {
        self.appConfiguration = appConfiguration
        self.internalQueue = OperationQueue()
        super.init()
        internalQueue.qualityOfService = qualityOfService
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
                    
                    for operation in redeemInviteOperations {
                        internalQueue.addOperation(operation)
                    }
                    try await internalQueue.drain()
                }
            } catch {
                Log.optional(error)
            }
                
            self.finish()
        }
    }
}
