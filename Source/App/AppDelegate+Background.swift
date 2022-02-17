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
    
    func handleBackgroundFetch(notificationsOnly: Bool = false, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.info("Handling background fetch")
        Analytics.shared.trackBackgroundFetch()
        let sendMissionOperation = SendMissionOperation(quality: .high)
        
        let refreshOperation = RefreshOperation(refreshLoad: .short)

        let statisticsOperation = StatisticsOperation()
        
        let operationQueue = OperationQueue()
        operationQueue.name = "Background Sync Queue"
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .background
        operationQueue.addOperations(
            [sendMissionOperation],
            waitUntilFinished: false
        )
        operationQueue.addOperation {
            Log.info("Sleeping 30 seconds so SendMissionOperation can run.")
            sleep(30)
            Log.info("Done sleeping")
        }
        operationQueue.addOperations([refreshOperation, statisticsOperation], waitUntilFinished: false)
        operationQueue.addOperation {
            Log.info("Completed background fetch")
            Analytics.shared.trackDidBackgroundFetch()
            
            switch (sendMissionOperation.result, !refreshOperation.isCancelled) {
            case (.success, true):
                completionHandler(.newData)
            default:
                completionHandler(.failed)
            }
        }
    }
    
}

extension AppDelegate {
    
    static let syncBackgroundTaskIdentifier = "com.planetary.sync"
    static let refreshBackgroundTaskIdentifier = "com.planetary.refresh"
    
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
//        self.scheduleRefreshTask()
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
        
        let sendMissionOperation = SendMissionOperation(quality: .high)

        let refreshOperation = RefreshOperation(refreshLoad: .short)

        let statisticsOperation = StatisticsOperation()
        
        task.expirationHandler = {
            Log.info("Task \(AppDelegate.syncBackgroundTaskIdentifier) expired")
            sendMissionOperation.cancel()
            refreshOperation.cancel()
            task.setTaskCompleted(success: false)
        }
        
        let operationQueue = OperationQueue()
        operationQueue.name = "Background Sync Queue"
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .background
        operationQueue.addOperations(
            [sendMissionOperation, refreshOperation, statisticsOperation],
            waitUntilFinished: false
        )
        operationQueue.addOperation {
            Log.info("Completed task \(AppDelegate.syncBackgroundTaskIdentifier)")

            switch (sendMissionOperation.result, !refreshOperation.isCancelled) {
            case (.success, true):
                task.setTaskCompleted(success: true)
            default:
                task.setTaskCompleted(success: false)
            }
        }
    }
}
