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
        
        let bot = Bots.current
        guard let appConfiguration = AppConfiguration.current,
            let loggedInIdentity = bot.identity,
            loggedInIdentity == appConfiguration.identity else {
            
            Log.info("Not logged in. SendMissionOperation finished.")
            self.result = .failure(BotError.notLoggedIn)
            self.finish()
            return
        }
        
        Task {
            let joinPlanetaryOperation = self.createJoinPlanetaryOperation(config: appConfiguration)
            let syncOperation = await self.createSyncOperation(bot: bot, config: appConfiguration)
            
            var operations: [Operation] = [syncOperation]
            if let joinPlanetaryOperation = joinPlanetaryOperation {
                syncOperation.addDependency(joinPlanetaryOperation)
                operations.append(joinPlanetaryOperation)
            }
            operationQueue.addOperations(operations, waitUntilFinished: false)
            try await operationQueue.drain()
            
            Log.info("SendMissionOperation finished.")
            self.result = .success(())
            self.finish()
        }
    }
    
    func createJoinPlanetaryOperation(config: AppConfiguration) -> JoinPlanetarySystemOperation? {
        JoinPlanetarySystemOperation(appConfiguration: config)
    }
    
    func createSyncOperation(bot: Bot, config: AppConfiguration) async -> SyncOperation {
        async let (rooms, pubs) = loadPeerPool(from: bot, config: config)
        let syncOperation = await SyncOperation(rooms: rooms, pubs: pubs)
        switch self.quality {
        case .low:
            syncOperation.notificationsOnly = true
        case .high:
            syncOperation.notificationsOnly = false
        }
        
        return syncOperation
    }
    
    func loadPeerPool(from bot: Bot, config: AppConfiguration) async -> ([MultiserverAddress], [MultiserverAddress]) {
        do {
            async let joinedRooms = bot.joinedRooms().map { $0.address }
            var joinedPubs = try await bot.joinedPubs().map { $0.address.multiserver }
            
            // If we don't have enough peers, supplement with the Planetary pubs
            let minPeers = JoinPlanetarySystemOperation.minNumberOfStars
            if joinedPubs.count < 1 {
                let systemPubs = Set(config.systemPubs).map { $0.address.multiserver }
                let someSystemPubs = systemPubs.randomSample(UInt(minPeers - joinedPubs.count))
                joinedPubs += someSystemPubs
            }
            
            return (try await joinedRooms, joinedPubs)
        } catch {
            Log.error("Error fetching joined rooms and pubs: \(error.localizedDescription)")
            CrashReporting.shared.reportIfNeeded(error: error)
            return ([], [])
        }
    }
}
