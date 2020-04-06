//
//  AppController+BackgroundSync.swift
//  Planetary
//
//  Created by Christoph on 1/10/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppController {

    /// Defines the constant used to  mark background tasks with a identifier that matches
    /// the app's Info.plist "Permitted background task scheduler identifiers".
    static let backgroundTaskIdentifier = "com.planetary.loginAndSync"
    
    /// Defines the constant used to label background task to display in the debugger
    static let backgroundTaskName = "LoginAndSyncTask"
    
    /// Sync the bot asking iOS to wait until the task finishes
    func loginAndSync(notificationsOnly: Bool = false, completion: ((Int) -> Void)? = nil) {
        let taskName = AppController.backgroundTaskName
        let task = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            // TODO: Stop login and sync, right now it is not supported
            //UIApplication.shared.endBackgroundTask(task)
        }
        
        guard task != UIBackgroundTaskIdentifier.invalid else {
            Log.info("Background tasks not supported")
            completion?(-1)
            return
        }
        
        Log.info("\(taskName) started")
        
        // TODO https://app.asana.com/0/914798787098068/1154847034386753/f
        // TODO ensure specified identity is the logged in one
        // TODO this is only necessary to support multiple accounts
        // TODO ensure that the bot downloads the notification's source message
        // TODO before forwarding the notification through the OS + app
        // TODO if already logged in should return quickly
        // log in first
        Bots.current.loginWithCurrentAppConfiguration() { didLogin in
            guard didLogin else {
                completion?(-1)
                Log.info("\(taskName) ended")
                UIApplication.shared.endBackgroundTask(task)
                return
            }
            if notificationsOnly {
                Bots.current.syncNotifications() { _, _, numberOfMessages in
                    completion?(numberOfMessages)
                    Log.info("\(taskName) ended with \(numberOfMessages) messages")
                    UIApplication.shared.endBackgroundTask(task)
                }
            } else {
                Bots.current.sync() { _, _, numberOfMessages in
                    completion?(numberOfMessages)
                    Log.info("\(taskName) ended with \(numberOfMessages) messages")
                    UIApplication.shared.endBackgroundTask(task)
                }
            }
        }
    }

    /// Same as `loginAndSync()` but  uses UIBackgroundFetchResult completion instead
    func backgroundFetch(notificationsOnly: Bool = false, completion: @escaping ((UIBackgroundFetchResult) -> Void)) {
        self.loginAndSync(notificationsOnly: notificationsOnly) { numberOfMessages in
            let result = self.backgroundFetchResult(for: numberOfMessages)
            completion(result)
        }
    }

    private func backgroundFetchResult(for numberOfMessages: Int) -> UIBackgroundFetchResult {
        switch numberOfMessages {
            case -1:    return .failed
            case 0:     return .noData
            default:    return .newData
        }
    }
}
