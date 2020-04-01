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
        AppController.shared.backgroundSync(completion: completionHandler)
    }

    // MARK: iOS 13+ support

    private func configureiOS13BackgroundTasks() {
        if #available(iOS 13, *) {
            let identifier = AppController.backgroundTaskLoginAndSync
            BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier,
                                            using: .main)
            {
                task in
                AppController.shared.backgroundSync() {
                    result in
                    task.setTaskCompleted(success: result != .failed)
                }
            }
        }
    }

    private func scheduleBackgroundSync() {
        if #available(iOS 13, *) {
            do {
                let identifier = AppController.backgroundTaskLoginAndSync
                let request = BGAppRefreshTaskRequest(identifier: identifier)
                try BGTaskScheduler.shared.submit(request)
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.optional(error, "Could not schedule task when entering background")
            }
        }
    }
}
