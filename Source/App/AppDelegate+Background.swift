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
        let backgroundSyncTask = startBackgroundSyncTask(long: false)
        Analytics.shared.trackDidStartBackgroundTask(taskIdentifier: "push-notification")
        
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
    
    static let shortSyncBackgroundTaskIdentifier = "com.planetary.short_sync"
    static let longSyncBackgroundTaskIdentifier = "com.planetary.long_sync"
    
    // MARK: Registering
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.shortSyncBackgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleSyncTask(task: task)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.longSyncBackgroundTaskIdentifier,
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
        // go-ssb cannot generally boot up quick enough to get data in the timeframe for a BGRefreshTask (which in
        // my testing only gets around 21-24 seconds before getting killed) so we are only scheduling the heavier
        // BGProcessingTasks for now.
        let longSyncRequest = BGProcessingTaskRequest(identifier: AppDelegate.longSyncBackgroundTaskIdentifier)
        longSyncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60) // 2 hours
        
        scheduleBackgroundTask(taskRequest: longSyncRequest)
    }
    
    private func scheduleBackgroundTask(taskRequest: BGTaskRequest) {
        do {
            Log.info(
                "Scheduling backgound task \(taskRequest.identifier) for " +
                "\(taskRequest.earliestBeginDate?.description ?? "nil")"
            )
            Analytics.shared.trackDidScheduleBackgroundTask(
                taskIdentifier: taskRequest.identifier,
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
        Log.info("Handling task \(task.identifier)")
        Analytics.shared.trackDidStartBackgroundTask(taskIdentifier: task.identifier)
        
        // Schedule a new sync task
        self.scheduleSyncTask()
        
        let backgroundSync = startBackgroundSyncTask(
            long: task.identifier == AppDelegate.longSyncBackgroundTaskIdentifier
        )
        task.expirationHandler = {
            Log.info("Background sync: Task \(task.identifier) expired")
            AppController.shared.missionControlCenter.cancelAll()
            Analytics.shared.trackDidCancelBackgroundSync()
            backgroundSync.cancel()
        }
        
        Task {
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
    private func startBackgroundSyncTask(long isLongSync: Bool) -> Task<Bool, Error> {
        Task { () -> Bool in
            Log.info("Background sync: starting.")
            let startDate = Date.now
            
            // Wait for login
            // this is terrible!
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            Log.info("Background sync: sending mission.")
            AppController.shared.missionControlCenter.sendMission()
            
            let goBot = Bots.current as? GoBot
            async let isBotStuck = goBot?.isBotStuck() ?? false
            
            // Sleep to allow time for syncing.
            let sleepSeconds: TimeInterval = isLongSync ? 120 : 20
            let sleepEndTime = Date(timeIntervalSince1970: startDate.timeIntervalSince1970 + sleepSeconds)
            Log.info("Background sync: sleeping \(sleepSeconds) seconds for replication.")
            try await Task.cancellableSleep(until: sleepEndTime, cancellationCheckInterval: 100_000_000)
            guard !Task.isCancelled else {
                return false
            }
            Log.info("Background sync: Done sleeping. Starting refresh.")
            
            AppController.shared.missionControlCenter.pokeRefresh()
            
            // Make sure that the bot is not stuck. #727
            if isLongSync {
                guard try await isBotStuck == false else {
                    Log.error("Background sync: GoBot is stuck, forcing a crash.")
                    Analytics.shared.trackBotDeadlock()
                    Analytics.shared.trackDidCompleteBackgroundSync(success: false, newMessageCount: 0)
                    CrashReporting.shared.reportIfNeeded(error: GoBotError.deadlock)
                    fatalError("Detected GoBot deadlock.")
                }
            }
            
            try await AppController.shared.operationQueue.drain()
        
            let newMessageCount = (try? Bots.current.numberOfNewMessages(since: startDate)) ?? 0

            Log.info("Completed background sync task successfully, received \(newMessageCount) messages.")
            Analytics.shared.trackDidCompleteBackgroundSync(success: true, newMessageCount: newMessageCount)
            return true
        }
    }
}
