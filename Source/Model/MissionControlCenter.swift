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
    
    /// State of a Mission Control Center object
    enum State {
        /// Timers are on and Mission Control Center is sending missions periodically
        case started
        
        /// Timers are paused
        case paused
        
        /// Timers are stopped and Mission Control Center won't send new missions until
        /// started again
        case stopped
    }
    
    /// Holds the state of the Mission Control Center
    private(set) var state: State = .stopped
    
    /// OperationQueue where SendMissionOperation and RefreshOperation are executed
    private let operationQueue = OperationQueue()
    
    /// Timer for the SendMissionOperation
    private lazy var sendMissionTimer: RepeatingTimer = {
        RepeatingTimer(interval: 60) { [weak self] in self?.sendMissions() }
    }()
    
    /// Timer for the RefreshOperation
    private lazy var refreshTimer: RepeatingTimer = {
        RepeatingTimer(interval: 17) { [weak self] in self?.pokeRefresh() }
    }()
    
    /// Background Task Identifier for the SendMissionOperation
    private var sendMissionBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    /// Background Task Identifier for the RefreshOperation
    private var refreshBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    /// Starts Mission Control Center operations. It starts timers and new missions.
    func start() {
        guard self.state == .stopped else {
            return
        }
        Log.info("Mission Control Center started operations")
        self.state = .started
        self.sendMissionTimer.start(fireImmediately: false)
        self.refreshTimer.start(fireImmediately: false)
        self.sendMission()
    }
    
    /// Resumes Mission Control Center operations. It resumes timers and starts a new missions.
    func resume() {
        guard self.state == .paused else {
            return
        }
        Log.info("Mission Control Center resumed operations")
        self.state = .started
        self.sendMissionTimer.start(fireImmediately: false)
        self.refreshTimer.start(fireImmediately: false)
        self.sendMission()
    }
    
    /// Pauses Mission Control Center operations. It pauses timers and cancels current missions.
    func pause() {
        guard self.state == .started else {
            return
        }
        Log.info("Mission Control Center paused operations")
        self.state = .paused
        self.sendMissionTimer.stop()
        self.refreshTimer.stop()
        self.operationQueue.addOperation(SuspendOperation())
    }
    
    /// Stops Mission Control Center operations. It pauses timers and cancels current missions.
    func stop() {
        guard self.state != .stopped else {
            return
        }
        Log.info("Mission Control Center stopped operations")
        self.state = .stopped
        self.sendMissionTimer.stop()
        self.refreshTimer.stop()
        self.operationQueue.addOperation(ExitOperation())
    }
    
    /// Sends an adhoc mission disregarding Mission Control Center state
    func sendMission() {
        Log.info("Mission Control Center is sending adhoc missions")
        let sendMissionOperation = SendMissionOperation(quality: .high)
        let refreshOperation = RefreshOperation(refreshLoad: .medium)
        refreshOperation.addDependency(sendMissionOperation)
        self.operationQueue.addOperations([sendMissionOperation, refreshOperation],
                                          waitUntilFinished: false)
    }
    
    private func sendMissions() {
        guard self.sendMissionBackgroundTaskIdentifier == .invalid else {
            Log.info("Mission Controller Center skipped a mission as there is one in progress.")
            return
        }
        
        Log.info("Mission Control Center is sending a mission")
        let sendMissionOperation = SendMissionOperation(quality: .high)
        
        let taskName = "SendMissionBackgroundTask"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            sendMissionOperation.cancel()
            UIApplication.shared.endBackgroundTask(self.sendMissionBackgroundTaskIdentifier)
            self.sendMissionBackgroundTaskIdentifier = .invalid
        }
        self.sendMissionBackgroundTaskIdentifier = taskIdentifier
        
        sendMissionOperation.completionBlock = {
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                self.sendMissionBackgroundTaskIdentifier = .invalid
            }
        }
        
        self.operationQueue.addOperation(sendMissionOperation)
    }
    
    private func pokeRefresh() {
        guard self.refreshBackgroundTaskIdentifier == .invalid else {
            Log.info("Mission Controller Center skipped a refresh as there is one in progress.")
            return
        }
        
        Log.info("Mission Control Center is doing a short refresh")
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        
        let taskName = "RefreshBackgroundTask"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(self.refreshBackgroundTaskIdentifier)
            self.refreshBackgroundTaskIdentifier = .invalid
        }
        self.refreshBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = {
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                self.refreshBackgroundTaskIdentifier = .invalid
            }
        }
        
        self.operationQueue.addOperation(refreshOperation)
    }
    
}
