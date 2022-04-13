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

/// Starts and/or cycles connections to pub servers. It also redeems invitations to the system pubs if the user
/// has opted in.
class SendMissionOperation: AsynchronousOperation {
    
    enum MissionQuality {
        case low
        case high
    }
    
    /// Switches how many connections are made and how many retries are considered
    var quality: MissionQuality
    
    /// Result of the operation
    private(set) var result: Result<Void, Error> = .failure(AppError.unexpected)
    
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
            let stars = Set(Environment.Constellation.stars)
            let allPubAddresses = stars.map { $0.address } + allJoinedPubs.map { $0.address }
            
            Bots.current.seedPubAddresses(addresses: allPubAddresses, queue: queue) { [weak self] result in
                if case .failure(let error) = result {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                }
                
                guard let self = self, let appConfiguration = AppConfiguration.current else {
                    return
                }
                
                let joinPlanetarySystemOperation = JoinPlanetarySystemOperation(
                    appConfiguration: appConfiguration,
                    operationQueue: self.operationQueue
                )
                
                let peerPool = allJoinedPubs.map { $0.toPeer() } + stars.map { $0.toPeer() }
                
                let syncOperation = SyncOperation(peerPool: peerPool)
                switch self.quality {
                case .low:
                    syncOperation.notificationsOnly = true
                case .high:
                    syncOperation.notificationsOnly = false
                }
                syncOperation.addDependency(joinPlanetarySystemOperation)
                
                let operations = [joinPlanetarySystemOperation, syncOperation]
                self.operationQueue.addOperations(operations, waitUntilFinished: true)
                
                Log.info("SendMissionOperation finished.")
                self.result = .success(())
                self.finish()
            }
        }
    }
}
