//
//  MissionControlCenter.swift
//  Planetary
//
//  Created by Martin Dutra on 8/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Manages sending missions to nearby stars
class MissionControlCenter {
    
    private let operationQueue = OperationQueue()
    
    enum State {
        case started
        case paused
        case stopped
    }
    
    private(set) var state: State = .stopped
    
    private lazy var syncTimer: RepeatingTimer = {
        RepeatingTimer(interval: 60) { [weak self] in self?.sendMissions() }
    }()
    
    private lazy var refreshTimer: RepeatingTimer = {
        RepeatingTimer(interval: 17) { [weak self] in self?.pokeRefresh() }
    }()
    
    private var syncPokeBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private var refreshPokeBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    func start() {
        guard self.state == .stopped else {
            return
        }
        self.state = .started
        self.syncTimer.start(fireImmediately: false)
        self.refreshTimer.start(fireImmediately: false)
        self.sendMission()
    }
    
    func resume() {
        guard self.state == .paused else {
            return
        }
        self.state = .started
        self.syncTimer.start(fireImmediately: false)
        self.refreshTimer.start(fireImmediately: false)
        self.sendMission()
    }
    
    func pause() {
        guard self.state == .started else {
            return
        }
        self.state = .paused
        self.syncTimer.stop()
        self.refreshTimer.stop()
        self.operationQueue.addOperation(SuspendOperation())
    }
    
    func stop() {
        guard self.state != .stopped else {
            return
        }
        self.state = .stopped
        self.syncTimer.stop()
        self.refreshTimer.stop()
        self.operationQueue.addOperation(ExitOperation())
    }
    
    func sendMission() {
        let sendMissionOperation = SendMissionOperation(quality: .high)
        let refreshOperation = RefreshOperation(refreshLoad: .tiny)
        refreshOperation.addDependency(sendMissionOperation)
        self.operationQueue.addOperations([sendMissionOperation, refreshOperation],
                                          waitUntilFinished: false)
    }
    
    private func sendMissions() {
        guard self.syncPokeBackgroundTaskIdentifier == .invalid else {
            Log.info("There is a sync poke still in progress. Skipping new poke.")
            return
        }
        
        Log.info("Poking the bot into doing a sync")
        let sendMissionOperation = SendMissionOperation(quality: .high)
        
        let taskName = "SyncPoke"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            sendMissionOperation.cancel()
            UIApplication.shared.endBackgroundTask(self.syncPokeBackgroundTaskIdentifier)
            self.syncPokeBackgroundTaskIdentifier = .invalid
        }
        self.syncPokeBackgroundTaskIdentifier = taskIdentifier
        
        sendMissionOperation.completionBlock = {
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                self.syncPokeBackgroundTaskIdentifier = .invalid
            }
        }
        
        self.operationQueue.addOperation(sendMissionOperation)
    }
    
    private func pokeRefresh() {
        guard self.refreshPokeBackgroundTaskIdentifier == .invalid else {
            Log.info("There is a refresh poke still in progress. Skipping new poke.")
            return
        }
        
        Log.info("Poking the bot into doing a tiny refresh")
        let refreshOperation = RefreshOperation()
        refreshOperation.refreshLoad = .tiny
        
        let taskName = "RefreshPoke"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(self.refreshPokeBackgroundTaskIdentifier)
            self.refreshPokeBackgroundTaskIdentifier = .invalid
        }
        self.refreshPokeBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = {
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                self.refreshPokeBackgroundTaskIdentifier = .invalid
            }
        }
        
        self.operationQueue.addOperation(refreshOperation)
    }
    
}
