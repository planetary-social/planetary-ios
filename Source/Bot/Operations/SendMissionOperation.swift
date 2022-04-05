//
//  SendMissionOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 8/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import CrashReporting

/// Starts and/or cycles connections to pub servers. It redeems invitations to the system pubs if the user
/// didn't do it previously.
class SendMissionOperation: AsynchronousOperation {
    
    enum MissionQuality {
        case low
        case high
    }
    
    /// Switches how many connections are made and how many retries are considered
    var quality: MissionQuality
    
    /// Result of the operation
    private(set) var result: Result<Void, Error> = .failure(AppError.unexpected)
    
    /// Minimum number of Planetary's pubs the users must have been invited to
    private static let minNumberOfStars = 3
    
    /// Internal operation queue meant for executing other operations
    private let operationQueue = OperationQueue()
    
    init(quality: MissionQuality) {
        self.quality = quality
        super.init()
    }
    
    override func main() {
        Log.info("SendMissionOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. SendMissionOperation finished.")
            self.result = .failure(BotError.notLoggedIn)
            self.finish()
            return
        }
        
        let queue = OperationQueue.current?.underlyingQueue ?? .global(qos: .background)
        
        Log.info("Retreiving all joined pubs from database.")
        Bots.current.joinedPubs(queue: queue) { (allJoinedPubs, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            Log.info("Sending all joined pubs to bot (\(allJoinedPubs.count)).")
            let systemPubs = Set(AppConfiguration.current?.systemPubs ?? [])
            let allPubAddresses = systemPubs.map { $0.address } + allJoinedPubs.map { $0.address }
            
            Bots.current.seedPubAddresses(addresses: allPubAddresses, queue: queue) { [weak self] result in
                if case .failure(let error) = result {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                }
                
                guard let self = self else {
                    return
                }
                
                // Get the stars the users already redeemed an invite to
                let joinedStars = systemPubs.filter { star in
                    allJoinedPubs.contains { (pub) -> Bool in
                        pub.address.key == star.feed
                    }
                }
                
                var starsToJoin = Set<Star>()
                var redeemInviteOperations = [RedeemInviteOperation]()
                
                // Join more stars if we haven't yet.
                let numberOfMissingStars = SendMissionOperation.minNumberOfStars - joinedStars.count
                if numberOfMissingStars > 0 {
                    Log.debug("Joining \(numberOfMissingStars) stars to get to minimum.")
                    
                    // Let's take a random set of stars to reach the minimum and create Redeem Invite
                    // operations
                    let missingStars = systemPubs.subtracting(joinedStars)
                    let randomSampleOfStars = missingStars.randomSample(UInt(numberOfMissingStars))
                    redeemInviteOperations = randomSampleOfStars.map {
                        RedeemInviteOperation(star: $0, shouldFollow: false)
                    }
                    
                    // Lets sync to available stars and newly redeemed stars
                    starsToJoin = missingStars
                }
                
                let peerPool = allJoinedPubs.compactMap {
                    $0.toPeer().multiserverAddress
                } + starsToJoin.compactMap {
                    $0.toPeer().multiserverAddress
                }
                
                let syncOperation = SyncOperation(peerPool: peerPool)
                switch self.quality {
                case .low:
                    syncOperation.notificationsOnly = true
                case .high:
                    syncOperation.notificationsOnly = false
                }
                redeemInviteOperations.forEach { syncOperation.addDependency($0) }
                
                let operations = redeemInviteOperations + [syncOperation]
                self.operationQueue.addOperations(operations, waitUntilFinished: true)
                
                Log.info("SendMissionOperation finished.")
                self.result = .success(())
                self.finish()
            }
        }
    }
}
