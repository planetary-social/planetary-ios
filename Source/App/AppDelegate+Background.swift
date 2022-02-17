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
        Analytics.shared.trackBackgroundFetch()
        
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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.syncBackgroundTaskIdentifier,
                                        using: nil) { task in
                                            self.handleSyncTask(task: task)
        }
    }
    
    // MARK: Scheduling
    
    private func scheduleBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        self.scheduleSyncTask()
    }
    
    private func scheduleSyncTask() {
        let syncTaskRequest = BGProcessingTaskRequest(identifier: AppDelegate.syncBackgroundTaskIdentifier)
        syncTaskRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        scheduleBackgroundTask(taskRequest: syncTaskRequest)
    }
    
    private func scheduleBackgroundTask(taskRequest: BGTaskRequest) {
        do {
            Log.info("Scheduling backgound task \(taskRequest.identifier) for \(taskRequest.earliestBeginDate?.description ?? "nil")")
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch BGTaskScheduler.Error.unavailable {
            // User could have just disabled background refresh in settings
            Log.info("Could not schedule task \(taskRequest.identifier). Background refresh is not permitted or running in simulator.")
        } catch let error {
            Log.optional(error, "Could not schedule task \(taskRequest.identifier)")
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }
    
    // MARK: Handling
    
    private func handleSyncTask(task: BGTask) {
        Log.info("Handling task \(AppDelegate.syncBackgroundTaskIdentifier)")
        Analytics.shared.trackDidBackgroundTask(taskIdentifier: AppDelegate.syncBackgroundTaskIdentifier)
        
        // Schedule a new sync task
        self.scheduleSyncTask()
        
        let backgroundSync = startBackgroundSyncTask()
        task.expirationHandler = {
            Log.info("Task \(AppDelegate.syncBackgroundTaskIdentifier) expired")
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
        return Task(priority: .background) { () -> Bool in
            let sendMissionOperation = SendMissionOperation(quality: .high)
            let refreshOperation = RefreshOperation(refreshLoad: .short)
            let statisticsOperation = StatisticsOperation()
            
            let operationQueue = OperationQueue()
            operationQueue.name = "Background Sync Queue"
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.qualityOfService = .background
            operationQueue.addOperations([sendMissionOperation], waitUntilFinished: false)
            await operationQueue.drainQueue()
                
            var sleepNanoseconds = 25_000_000_000
            Log.info("Sleeping \(sleepNanoseconds / 1_000_000_000) seconds so SendMissionOperation can run.")
            
            while sleepNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    Log.optional(error, "Failed to complete background task")
                    return false
                }
                
                if Task.isCancelled {
                    refreshOperation.cancel()
                    statisticsOperation.cancel()
                    Log.info("Background sync task canceled")
                    return false
                }
                sleepNanoseconds -= 100_000_000
            }
            Log.info("Done sleeping")
            
            operationQueue.addOperations([refreshOperation, statisticsOperation], waitUntilFinished: false)
            
            await operationQueue.drainQueue()
        
            Analytics.shared.trackDidBackgroundFetch()

            switch (sendMissionOperation.result, !refreshOperation.isCancelled) {
            case (.success, true):
                Log.info("Completed background sync task")
                return true
            default:
                return false
            }
        }
    }
}
