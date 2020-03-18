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

    /// Defines the constant used to  mark background tasks with a  name that matches
    /// the app's Info.plist "Permitted background task scheduler identifiers".
    static let backgroundTaskLoginAndSync = "com.planetary.loginAndSync"

    // no analytics
    // wraps in BGTask, but what if there is already a task?
    // can this take a task to complete?
    func loginAndSync(notificationsOnly: Bool = false,
                      completion: ((Int) -> Void)? = nil)
    {
        let taskName = AppController.backgroundTaskLoginAndSync
        let task = UIApplication.shared.beginBackgroundTask(withName: taskName)

        // TODO https://app.asana.com/0/914798787098068/1154847034386753/f
        // TODO ensure specified identity is the logged in one
        // TODO this is only necessary to support multiple accounts
        // TODO ensure that the bot downloads the notification's source message
        // TODO before forwarding the notification through the OS + app
        // TODO if already logged in should return quickly
        // log in first
        Bots.current.loginWithCurrentAppConfiguration() {
            [weak self] didLogin in
            guard didLogin else { completion?(-1); return }

            if notificationsOnly {
                self?.syncNotifications(task: task, completion: completion)
            } else {
                self?.syncEverything(task: task, completion: completion)
            }
        }
    }

    private func syncEverything(task: UIBackgroundTaskIdentifier,
                                completion: ((Int) -> Void)? = nil)
    {
        Bots.current.sync() {
            _, _, numberOfMessages in
            completion?(numberOfMessages)
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    private func syncNotifications(task: UIBackgroundTaskIdentifier,
                                   completion: ((Int) -> Void)? = nil)
    {
        Bots.current.syncNotifications() {
            _, _, numberOfMessages in
            completion?(numberOfMessages)
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    /// Similar to `loginAndSync()` but includes analytics indicating this was called from
    /// a background process.
    func backgroundSync(notificationsOnly: Bool = false,
                        completion: @escaping ((UIBackgroundFetchResult) -> Void))
    {
        Analytics.trackAppStartBackgroundSync()
        self.loginAndSync(notificationsOnly: notificationsOnly) {
            numberOfMessages in
            let result = self.backgroundFetchResult(for: numberOfMessages)
            completion(result)
            Analytics.trackAppDidBackgroundSync(numberOfMessages: numberOfMessages,
                                                notificationsOnly: notificationsOnly)
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
