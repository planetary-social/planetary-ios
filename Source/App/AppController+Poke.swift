//
//  AppController+Poke.swift
//  Planetary
//
//  Created by Martin Dutra on 4/28/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppController {
    
    static var syncPokeBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    static var refreshPokeBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    /// See Timers.pokeTimer, this is executed in foreground every one minute
    /// Pokes the bot into doing a sync, but only if logged in, and only if
    /// not during an onboarding process.
    func pokeSync() {
        guard let identity = Bots.current.identity else { return }
        guard Onboarding.status(for: identity) == .completed else { return }
        
        guard AppController.syncPokeBackgroundTaskIdentifier == .invalid else {
            Log.info("There is a sync poke still in progress. Skipping new poke.")
            return
        }
        
        Log.info("Poking the bot into doing a sync")
        let syncOperation = SyncOperation()
        
        let taskName = "SyncPoke"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            syncOperation.cancel()
            UIApplication.shared.endBackgroundTask(AppController.syncPokeBackgroundTaskIdentifier)
            AppController.syncPokeBackgroundTaskIdentifier = .invalid
        }
        AppController.syncPokeBackgroundTaskIdentifier = taskIdentifier
        
        syncOperation.completionBlock = {
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                AppController.syncPokeBackgroundTaskIdentifier = .invalid
            }
        }
        
        self.operationQueue.addOperation(syncOperation)
    }
    
    func pokeRefresh() {
        guard let identity = Bots.current.identity else { return }
        guard Onboarding.status(for: identity) == .completed else { return }
        
        guard AppController.refreshPokeBackgroundTaskIdentifier == .invalid else {
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
            UIApplication.shared.endBackgroundTask(AppController.refreshPokeBackgroundTaskIdentifier)
            AppController.refreshPokeBackgroundTaskIdentifier = .invalid
        }
        AppController.refreshPokeBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = {
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                AppController.refreshPokeBackgroundTaskIdentifier = .invalid
            }
        }
        
        self.operationQueue.addOperation(refreshOperation)
    }
    
}
