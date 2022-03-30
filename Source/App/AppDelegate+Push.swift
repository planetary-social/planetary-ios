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
import Logger
import Analytics
import CrashReporting

// https://github.com/planetary-social/infrastructure/wiki/Apple-Push-Notification-Infrastructure
extension AppDelegate: UNUserNotificationCenterDelegate {

    func configureNotifications() {
        UNUserNotificationCenter.current().delegate = self
        self.addReportsObservers()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AppController.shared.updatePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        guard UIDevice.isSimulator == false else { return }
        Log.fatal(.apiError, "Could not register for push notifications: \(error)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // only support silent notifications for now
        guard userInfo.aps.isContentAvailable else {
            completionHandler(.noData)
            return
        }
        
        Log.info("Triggering background sync from silent push notification")
        Analytics.shared.trackDidReceiveRemoteNotification()
        handleBackgroundFetch(completionHandler: completionHandler)
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
        
        // badge is incremented regardless of foreground/background
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber += 1
            AppController.shared.mainViewController?.updateNotificationsTabIcon(hasNotifications: true)
        }

        // schedule the notification
        UNUserNotificationCenter.current().add(request) {
            error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
        }
    }
    
    /// Transforms a report into a scheduled `UNNotificationRequest` that the human
    /// can interact with.
    func scheduleLocalNotification(_ report: Report) {
        
        Bots.current.about(queue: .global(qos: .background), identity: report.keyValue.value.author) { (about, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            let content = UNMutableNotificationContent()
            
            let who = about?.nameOrIdentity ?? Text.Report.somebody.text
            
            switch report.reportType {
            case .feedFollowed:
                content.title = NSString.localizedUserNotificationString(forKey: Text.Report.feedFollowed.text,
                                                                         arguments: [who])
            case .postReplied:
                content.title = NSString.localizedUserNotificationString(forKey: Text.Report.postReplied.text,
                                                                         arguments: [who])
                if let what = report.keyValue.value.content.post?.text {
                    content.body = what.withoutGallery().decodeMarkdown().string
                }
            case .feedMentioned:
                content.title = NSString.localizedUserNotificationString(forKey: Text.Report.feedMentioned.text,
                                                                         arguments: [who])
                if let what = report.keyValue.value.content.post?.text {
                    content.body = what.withoutGallery().decodeMarkdown().string
                }
            case .messageLiked:
                content.title = NSString.localizedUserNotificationString(forKey: Text.Report.messageLiked.text,
                                                                         arguments: [who])
            }
            
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(identifier: report.messageIdentifier,
                                                content: content,
                                                trigger: nil)

            // schedule the notification
            UNUserNotificationCenter.current().add(request) {
                error in
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.optional(error)
            }
        }
    }

    /// If the response is the default "tap" interaction, forwards the notification to the AppController.
    /// Note that when this is called, the OS is transitioning the app from the background, and any
    /// asynchronous operations are not guaranteed to be completed before the UI is visible.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        AppController.shared.received(backgroundNotification: response.notification)
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    // MARK: Reports
    
    private func addReportsObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didCreateReportHandler(notification:)),
                                               name: .didCreateReport,
                                               object: nil)
    }
    
    @objc func didCreateReportHandler(notification: Notification) {
        guard let report = notification.userInfo?["report"] as? Report else {
            return
        }
        guard let currentIdentity = Bots.current.identity else {
            // Don't do anything if user is not logged in
            return
        }
        guard report.authorIdentity == currentIdentity else {
            // Don't do anything if report is not for the logged in user
            return
        }
        self.scheduleLocalNotification(report)
        print("RECEIVED REPORT!: \(report)")
    }
}
