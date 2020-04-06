//
//  AppDelegate+Push.swift
//  FBTT
//
//  Created by Christoph on 8/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import UserNotificationsUI

extension AppDelegate: UNUserNotificationCenterDelegate {

    func configureNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        AppController.shared.updatePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        guard UIDevice.isSimulator == false else { return }
        Log.fatal(.apiError, "Could not register for push notifications: \(error)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        // only support silent notifications for now
        guard userInfo.aps.isContentAvailable else {
            completionHandler(.noData)
            return
        }

        // do a background sync, refresh then handle the notification
        AppController.shared.backgroundFetch(notificationsOnly: true) {
            [weak self] result in
            Bots.current.refresh() { _, _ in
                self?.handle(notification: userInfo, in: application.applicationState)
                completionHandler(result)
            }
        }
    }

    private func handle(notification: RemoteNotificationUserInfo,
                        in state: UIApplication.State)
    {
        // only supported viewable notifications should be forwarded to the app
        guard notification.isSupported else {
            Log.fatal(.incorrectValue, "Received unsupported remote notification with type: \(notification.rawType)")
            return
        }

        // badge is incremented regardless of foreground/background
        UIApplication.shared.applicationIconBadgeNumber += 1

        switch state {
            case .background:
                self.scheduleLocalNotification(notification)
                break

            default:
                AppController.shared.received(foregroundNotification: notification)
        }
    }

    // MARK: Local notification

    /// Transforms the remote notication into a scheduled `UNNotificationRequest` that the human
    /// can interact with.  Note that the notification should be validated `RemoteNotificationUserInfo.isViewable`
    /// before getting to this step.
    private func scheduleLocalNotification(_ notification: RemoteNotificationUserInfo) {

        // if the notification content structure changes it is possible
        // that an empty content is posted, not sure how the OS treats that
        let content = UNMutableNotificationContent()
        if let title = notification.title { content.title = title }
        if let body = notification.body { content.body = body }
        content.sound = UNNotificationSound.default

        // for now use a random UUID string, not sure what else to do
        // in the future this should probably be the SSB message identifier
        let identifier = UUID().uuidString
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier,
                                            content: content,
                                            trigger: trigger)

        // schedule the notification
        UNUserNotificationCenter.current().add(request) {
            error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
        }
    }

    /// If the response is the default "tap" interaction, forwards the notification to the AppController.
    /// Note that when this is called, the OS is transitioning the app from the background, and any
    /// asynchronous operations are not guaranteed to be completed before the UI is visible.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        AppController.shared.received(backgroundNotification: response.notification)
    }
}
