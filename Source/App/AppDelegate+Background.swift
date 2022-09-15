//
//  AppDelegate+Background.swift
//  Planetary
//
//  Created by Christoph on 12/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import BackgroundTasks
import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

extension AppDelegate {

    /// This must be called during `AppDelegate.application(didFinishLaunchingWithOptions)`.
    func configureBackgroundAppRefresh() {
        registerBackgroundTasks()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        CrashReporting.shared.record("App did enter background")
        AppController.shared.suspend()
        if #available(iOS 13, *) {
            self.scheduleBackgroundTasks()
        }
        Analytics.shared.trackAppBackground()
    }
}

extension AppDelegate {
    
    func handleBackgroundFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let backgroundSyncTask = startBackgroundSyncTask()
        
        Task.detached(priority: .background) {
            let result = await backgroundSyncTask.result

            switch result {
            case .success(let finished) where finished:
                completionHandler(.newData)
            case .failure, .success:
                completionHandler(.failed)
            }
        }
    }
}

extension AppDelegate {
    
    static let syncBackgroundTaskIdentifier = "com.planetary.sync"
    
    // MARK: Registering
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.syncBackgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleSyncTask(task: task)
        }
    }
    
    // MARK: Scheduling
    
    private func scheduleBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        self.scheduleSyncTask()
    }
    
    private func scheduleSyncTask() {
        let syncTaskRequest = BGAppRefreshTaskRequest(identifier: AppDelegate.syncBackgroundTaskIdentifier)
        syncTaskRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 120) // 2 hours
        scheduleBackgroundTask(taskRequest: syncTaskRequest)
    }
    
    private func scheduleBackgroundTask(taskRequest: BGTaskRequest) {
        do {
            Log.info(
                "Scheduling backgound task \(taskRequest.identifier) for " +
                "\(taskRequest.earliestBeginDate?.description ?? "nil")"
            )
            Analytics.shared.trackDidScheduleBackgroundTask(
                taskIdentifier: AppDelegate.syncBackgroundTaskIdentifier,
                for: taskRequest.earliestBeginDate
            )
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch BGTaskScheduler.Error.unavailable {
            // User could have just disabled background refresh in settings
            Log.info(
                "Could not schedule task \(taskRequest.identifier). " +
                "Background refresh is not permitted or running in simulator."
            )
        } catch {
            Log.optional(error, "Could not schedule task \(taskRequest.identifier)")
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }
    
    // MARK: Handling
    
    // To test this, run on a real device, hit pause in the debugger, then paste in this command:
    // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.planetary.sync"]
    private func handleSyncTask(task: BGTask) {
        Log.info("Handling task \(AppDelegate.syncBackgroundTaskIdentifier)")
        Analytics.shared.trackDidStartBackgroundTask(taskIdentifier: AppDelegate.syncBackgroundTaskIdentifier)
        
        // Schedule a new sync task
        self.scheduleSyncTask()
        
        let backgroundSync = startBackgroundSyncTask()
        task.expirationHandler = {
            Log.info("Task \(AppDelegate.syncBackgroundTaskIdentifier) expired")
            Analytics.shared.trackDidCancelBackgroundSync()
            backgroundSync.cancel()
        }
        
        Task.detached {
            let result = await backgroundSync.result
            
            switch result {
            case .success(let finished):
                task.setTaskCompleted(success: finished)
            case .failure:
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    /// Starts a background Task that will give the GoBot some time to sync with peers. Intended to be used when the
    /// app is not in the foreground.
    private func startBackgroundSyncTask() -> Task<Bool, Error> {
        Task(priority: .background) { () -> Bool in
            Log.info("Starting background sync.")
            let startDate = Date.now
            
            // Wait for login
            // this is terrible!
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            AppController.shared.missionControlCenter.sendMission()
            
            let goBot = Bots.current as? GoBot
            async let isBotStuck = goBot?.isBotStuck() ?? false
            
            // Sleep to allow time for syncing.
            let sleepSeconds: TimeInterval = 20
            let sleepEndTime = Date(timeIntervalSince1970: startDate.timeIntervalSince1970 + sleepSeconds)
            Log.info("Sleeping \(sleepSeconds) seconds so SendMissionOperation can run.")
            try await Task.cancellableSleep(until: sleepEndTime, cancellationCheckInterval: 100_000_000)
            guard !Task.isCancelled else {
                Analytics.shared.trackDidCompleteBackgroundSync(success: false, newMessageCount: 0)
                Log.info("Background sync task canceled")
                return false
            }
            Log.info("Done sleeping")
            
            // Make sure that the bot is not stuck. #727
            guard try await isBotStuck == false else {
                Log.error("GoBot is stuck, forcing a crash.")
                Analytics.shared.trackBotDeadlock()
                Analytics.shared.trackDidCompleteBackgroundSync(success: false, newMessageCount: 0)
                CrashReporting.shared.reportIfNeeded(error: GoBotError.deadlock)
                fatalError("Detected GoBot deadlock.")
            }
            
            AppController.shared.missionControlCenter.pokeRefresh()
            
            try await AppController.shared.operationQueue.drain()
        
            let newMessageCount = (try? Bots.current.numberOfNewMessages(since: startDate)) ?? 0

            Log.info("Completed background sync task successfully, received \(newMessageCount) messages.")
            Analytics.shared.trackDidCompleteBackgroundSync(success: true, newMessageCount: newMessageCount)
            return true
        }
    }
}
