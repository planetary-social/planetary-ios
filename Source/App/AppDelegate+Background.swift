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
    func configureBackground() {
        self.configureBackgroundFetch()
        if #available(iOS 13, *) {
            self.registerBackgroundTasks()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        CrashReporting.shared.record("App did enter background")
        AppController.shared.suspend()
        if #available(iOS 13, *) {
            self.scheduleBackgroundTasks()
        }
        Analytics.shared.trackAppBackground()
    }

    /// Sometimes this is called during launch, and will error with `BotError.notLoggedIn`.  Leaving this in to learn from analytics how
    /// often this is called.
    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        self.handleBackgroundFetch(completionHandler: completionHandler)
    }
    
}

extension AppDelegate {
    
    /// Configures background fetch internal to be an hour, however this is not a guarantee as the OS
    /// will give time depending on how often new data is returned.
    func configureBackgroundFetch() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    func handleBackgroundFetch(notificationsOnly: Bool = false, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.info("Handling background fetch")
        Analytics.shared.trackBackgroundFetch()
        let sendMissionOperation = SendMissionOperation(quality: .low)
        
        let refreshOperation = RefreshOperation(refreshLoad: .medium)

        let statisticsOperation = StatisticsOperation()
        
        let operationQueue = OperationQueue()
        DispatchQueue.global(qos: .background).async {
            operationQueue.addOperations([sendMissionOperation, refreshOperation, statisticsOperation],
                                         waitUntilFinished: true)
            Log.info("Completed background fetch")
            Analytics.shared.trackDidBackgroundFetch()
            switch sendMissionOperation.result {
            case .success:
                completionHandler(.newData)
            case .failure:
                completionHandler(.failed)
            }
        }
    }
    
}

@available(iOS 13.0, *)
extension AppDelegate {
    
    static let syncBackgroundTaskIdentifier = "com.planetary.sync"
    static let refreshBackgroundTaskIdentifier = "com.planetary.refresh"
    
    // MARK: Registering
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.syncBackgroundTaskIdentifier,
                                        using: nil) { task in
                                            self.handleSyncTask(task: task)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.refreshBackgroundTaskIdentifier,
                                        using: nil) { task in
                                            self.handleRefreshTask(task: task)
        }
    }
    
    // MARK: Scheduling
    
    private func scheduleBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        self.scheduleSyncTask()
        self.scheduleRefreshTask()
    }
    
    private func scheduleSyncTask() {
        let syncTaskRequest = BGAppRefreshTaskRequest(identifier: AppDelegate.syncBackgroundTaskIdentifier)
        syncTaskRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        scheduleBackgroundTask(taskRequest: syncTaskRequest)
    }
    
    private func scheduleRefreshTask() {
        let refreshTaskRequest = BGProcessingTaskRequest(identifier: AppDelegate.refreshBackgroundTaskIdentifier)
        refreshTaskRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        scheduleBackgroundTask(taskRequest: refreshTaskRequest)
    }
    
    private func scheduleBackgroundTask(taskRequest: BGTaskRequest) {
        do {
            Log.info("Scheduling task \(taskRequest.identifier)")
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
    
    @available(iOS 13.0, *)
    private func handleSyncTask(task: BGTask) {
        Log.info("Handling task \(AppDelegate.syncBackgroundTaskIdentifier)")
        Analytics.shared.trackBackgroundTask()
        
        // Schedule a new sync task
        self.scheduleSyncTask()
        
        let sendMissionOperation = SendMissionOperation(quality: .high)

        let refreshOperation = RefreshOperation(refreshLoad: .medium)

        let statisticsOperation = StatisticsOperation()
        
        task.expirationHandler = {
            Log.info("Task \(AppDelegate.syncBackgroundTaskIdentifier) expired")
            sendMissionOperation.cancel()
            refreshOperation.cancel()
        }
        
        let operationQueue = OperationQueue()
        DispatchQueue.global(qos: .background).async {
            operationQueue.addOperations([sendMissionOperation, refreshOperation, statisticsOperation],
                                         waitUntilFinished: true)
            Log.info("Completed task \(AppDelegate.syncBackgroundTaskIdentifier)")
            Analytics.shared.trackDidBackgroundTask(taskIdentifier: AppDelegate.syncBackgroundTaskIdentifier)
            task.setTaskCompleted(success: !sendMissionOperation.isCancelled)
        }
    }
    
    @available(iOS 13.0, *)
    private func handleRefreshTask(task: BGTask) {
        Log.info("Handling task \(AppDelegate.refreshBackgroundTaskIdentifier)")
        Analytics.shared.trackBackgroundTask()
        
        // Schedule a new sync task
        self.scheduleRefreshTask()
        
        let refreshOperation = RefreshOperation(refreshLoad: .medium)
        
        task.expirationHandler = {
            Log.info("Task \(AppDelegate.refreshBackgroundTaskIdentifier) expired")
            refreshOperation.cancel()
        }
        
        refreshOperation.completionBlock = {
            Log.info("Completed task \(AppDelegate.refreshBackgroundTaskIdentifier)")
            Analytics.shared.trackDidBackgroundTask(taskIdentifier: AppDelegate.refreshBackgroundTaskIdentifier)
            task.setTaskCompleted(success: !refreshOperation.isCancelled)
        }
        let operationQueue = OperationQueue()
        operationQueue.addOperation(refreshOperation)
    }
    
}
