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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AppController.shared.updatePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        guard UIDevice.isSimulator == false else { return }
        Log.fatal(.apiError, "Could not register for push notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
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
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
        }
    }
    
    /// Transforms a report into a scheduled `UNNotificationRequest` that the human
    /// can interact with.
    func scheduleLocalNotification(_ report: Report) {
        Bots.current.about(queue: .global(qos: .background), identity: report.message.author) { (about, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            let content = UNMutableNotificationContent()
            
            let nameToShow = about?.nameOrIdentity ?? Text.Report.somebody.text

            // swiftlint:disable legacy_objc_type
            switch report.reportType {
            case .feedFollowed:
                content.title = NSString.localizedUserNotificationString(
                    forKey: Text.Report.feedFollowed.text,
                    arguments: [nameToShow]
                )
            case .postReplied:
                content.title = NSString.localizedUserNotificationString(
                    forKey: Text.Report.postReplied.text,
                    arguments: [nameToShow]
                )
                if let what = report.message.content.post?.text {
                    content.body = what.withoutGallery().decodeMarkdown().string
                }
            case .feedMentioned:
                content.title = NSString.localizedUserNotificationString(
                    forKey: Text.Report.feedMentioned.text,
                    arguments: [nameToShow]
                )
                if let what = report.message.content.post?.text {
                    content.body = what.withoutGallery().decodeMarkdown().string
                }
            case .messageLiked:
                content.title = NSString.localizedUserNotificationString(
                    forKey: Text.Report.messageLiked.text,
                    arguments: [nameToShow]
                )
            }
            // swiftlint:enable legacy_objc_type
            
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(identifier: report.messageIdentifier, content: content, trigger: nil)

            // schedule the notification
            UNUserNotificationCenter.current().add(request) { error in
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.optional(error)
            }
        }
    }

    /// If the response is the default "tap" interaction, forwards the notification to the AppController.
    /// Note that when this is called, the OS is transitioning the app from the background, and any
    /// asynchronous operations are not guaranteed to be completed before the UI is visible.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        AppController.shared.mainViewController?.selectNotificationsTab()
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    // MARK: Reports
    
    private func addReportsObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didCreateReportHandler(notification:)),
            name: .didCreateReport,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didUpdateReportReadStatus(notification:)),
            name: .didUpdateReportReadStatus,
            object: nil
        )
    }
    
    @objc
    func didCreateReportHandler(notification: Notification) {
        guard let reports = notification.userInfo?["reports"] as? [Report] else {
            return
        }
        guard let currentIdentity = Bots.current.identity else {
            // Don't do anything if user is not logged in
            return
        }
        guard !Bots.current.isRestoring else {
            // Suppress notifications if the user is restoring
            return
        }
        guard reports.contains(where: { $0.authorIdentity == currentIdentity }) else {
            // Don't do anything if none of the reports are for the logged in user
            return
        }

        // Update the application badge number
        updateApplicationBadgeNumber()

        Bots.current.blocks(identity: currentIdentity) { [weak self] blockedIdentities, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            reports.forEach { [weak self] report in
                let notifyingIdentity = report.message.author
                let notifiedIdentity = report.authorIdentity
                guard notifiedIdentity == currentIdentity, !blockedIdentities.contains(notifyingIdentity) else {
                    return
                }
                // Display a local notification so the user is aware of a new report
                self?.scheduleLocalNotification(report)
            }
        }
    }

    @objc
    func didUpdateReportReadStatus(notification: Notification) {
        // We get this notification after the user read a report that was previously unread, so its time to check the
        // total number of unread reports and update the badge number
        updateApplicationBadgeNumber()
    }

    private func updateApplicationBadgeNumber() {
        let operation = CountUnreadNotificationsOperation()
        AppController.shared.addOperation(operation)
    }
}
