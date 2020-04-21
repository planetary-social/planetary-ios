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
        self.configureiOS12BackgroundTasks()
        self.configureiOS13BackgroundTasks()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppController.shared.suspend()
        self.scheduleBackgroundSync()
        Analytics.trackAppBackground()
    }

    // MARK: iOS 12 and lower support

    /// Configures background fetch internal to be an hour, however this is not a guarantee as the OS
    /// will give time depending on how often new data is returned.
    private func configureiOS12BackgroundTasks() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }

    // TODO https://app.asana.com/0/914798787098068/1144986520928091/f
    // iOS 13 does this different for background notifications
    /// When called by the OS, asks the bot to sync and refresh, and tracking the resulting duration and number of new messages.
    /// Sometimes this is called during launch, and will error with `BotError.notLoggedIn`.  Leaving this in to learn from analytics how
    /// often this is called.
    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        Log.info("Background fetch")
        AppController.shared.backgroundFetch(completion: completionHandler)
    }

    // MARK: iOS 13+ support

    private func configureiOS13BackgroundTasks() {
        if #available(iOS 13, *) {
            let taskIdentifier = AppController.backgroundTaskIdentifier
            Log.info("Registering task \(taskIdentifier)")
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: .main) { [weak self] task in
                Log.info("Executing task \(taskIdentifier)")
                self?.scheduleBackgroundSync()
                
                task.expirationHandler = {
                    // Expiry handler, iOS will call this shortly before ending the task
                    // TODO: Stop backgroundFetch, right now it is not supported
                }
                AppController.shared.backgroundFetch() { result in
                    task.setTaskCompleted(success: result != .failed)
                }
            }
        }
    }

    private func scheduleBackgroundSync() {
        if #available(iOS 13, *) {
            do {
                let taskIdentifier = AppController.backgroundTaskIdentifier
                let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
                
                // Fetch no earlier than 5 minutes from now
                request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
                
                Log.info("Scheduling task \(taskIdentifier)")
                try BGTaskScheduler.shared.submit(request)
            } catch BGTaskScheduler.Error.unavailable {
                // User could have just disabled background refresh in settings
                Log.info("Background refresh are not permitted")
            } catch let error {
                Log.optional(error, "Could not schedule a refresh task when entering background")
                CrashReporting.shared.reportIfNeeded(error: error)
            }
        }
    }
}
