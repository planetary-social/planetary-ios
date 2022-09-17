//
//  MissionControlCenter.swift
//  Planetary
//
//  Created by Martin Dutra on 8/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

/// Manages connections to other peers aka sending missions to nearby stars.
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
    let operationQueue = OperationQueue()
    
    /// Timer for the SendMissionOperation
    private lazy var sendMissionTimer: RepeatingTimer = {
        RepeatingTimer(interval: 60) { [weak self] in self?.sendMissions() }
    }()
    
    /// Timer for the RefreshOperation
    private lazy var refreshTimer: RepeatingTimer = {
        RepeatingTimer(interval: 5) { [weak self] in self?.pokeRefresh() }
    }()
    
    /// Starts Mission Control Center operations. It starts timers and new missions.
    func start() {
        guard self.state == .stopped else {
            return
        }
        Log.info("Mission Control Center started operations")
        self.state = .started
        self.sendMissionTimer.start(fireImmediately: true)
        self.refreshTimer.start(fireImmediately: true)
    }
    
    /// Resumes Mission Control Center operations. It resumes timers and starts a new missions.
    func resume() {
        guard self.state == .paused else {
            return
        }
        Log.info("Mission Control Center resumed operations")
        self.state = .started
        self.sendMissionTimer.start(fireImmediately: true)
        self.refreshTimer.start(fireImmediately: true)
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
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        refreshOperation.addDependency(sendMissionOperation)
        self.operationQueue.addOperations([sendMissionOperation, refreshOperation],
                                          waitUntilFinished: false)
    }
    
    private func sendMissions() {
        guard !operationQueue.operations.contains(where: { $0 is SendMissionOperation }) else {
            Log.info("Mission Controller Center skipped a mission as there is one in progress.")
            return
        }
        
        Log.info("Mission Control Center is sending a mission")
        let sendMissionOperation = SendMissionOperation(quality: .high)
        operationQueue.addOperation(sendMissionOperation)
    }
    
    func pokeRefresh() {
        guard !operationQueue.operations.contains(where: { $0 is RefreshOperation }) else {
            Log.info("Mission Controller Center skipped a refresh as there is one in progress.")
            return
        }
        
        Log.info("Mission Control Center is doing a short refresh")
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        operationQueue.addOperation(refreshOperation)
    }
}
