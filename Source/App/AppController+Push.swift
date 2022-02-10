//
//  AppController+Push.swift
//  FBTT
//
//  Created by Christoph on 8/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import Logger

extension AppController {

    static let pushNotificationOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

    /// Queries the OS notification settings and returns a simplified bool indicating status.
    /// If the authorization status has not been determined, the value will be false.  This
    /// will allow UI, like a toggle, to show the state as disabled.
    func arePushNotificationsEnabled(completion: @escaping ((Bool) -> Void)) {
        UNUserNotificationCenter.current().getNotificationSettings() {
            settings in
            let enabled = settings.authorizationStatus == .authorized
            DispatchQueue.main.async { completion(enabled) }
        }
    }

    /// Queries the OS notification settings and if the authorization status has not been determined,
    /// prompts via the usual OS prompt.  However, if it has been determined, nothing else is done.
    func promptForPushNotificationsIfNotDetermined(in viewController: UIViewController? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings() {
            settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    self.registerForPushNotifications()
                }
            }
        }
    }

    /// Queries the OS notification settings and if the authorization status has not been determined,
    /// prompts for authorization via the typical OS prompt.  Once this has been called and the
    /// user has made a choice, subsequent calls will not prompt unless the OS resets the
    /// authorization status (which can happen when the OS is updated).  The authorization
    /// status will be returned once the user has interacted with any prompts.
    func promptForPushNotifications(in viewController: UIViewController? = nil,
                                    completion: ((UNAuthorizationStatus) -> Void)? = nil)
    {
        UNUserNotificationCenter.current().getNotificationSettings() {
            settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                    case .notDetermined:    self.registerForPushNotifications(completion: completion)
                    default:                self.promptToOpenSettings(in: viewController,
                                                                      status: settings.authorizationStatus,
                                                                      completion: completion)
                }
            }
        }
    }

    /// Prompts to open the OS Settings app with the explanation that push notification settings
    /// are controlled there.  If cancelled, the supplied status is returned in the completion, allowing
    /// UI to revert any changes (like when a toggle is tapped).  This should only be called if the
    /// authorization status has been determined previously.
    private func promptToOpenSettings(in viewController: UIViewController? = nil,
                                      status: UNAuthorizationStatus,
                                      completion: ((UNAuthorizationStatus) -> Void)? = nil)
    {
        let controller = viewController ?? self
        controller.confirm(
            title: Text.Push.title.text,
            message: Text.Push.prompt.text,
            isDestructive: false,
            cancelClosure: { completion?(status) },
            confirmTitle: Text.settings.text,
            confirmClosure: AppController.shared.openOSSettings
        )
    }

    /// Queries the OS push notification settings, and if authorized or denied, updates the PushAPI.
    func syncPushNotificationsSettings() {
        UNUserNotificationCenter.current().getNotificationSettings() {
            settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                    case .authorized: UIApplication.shared.registerForRemoteNotifications()
                    case .denied: self.deregisterForPushNotifications()
                    default: break
                }
            }
        }
    }

    /// Called when promptForPushNotifications() has determined that authorization
    /// status has not been determined.  This will present the OS prompt for permission.
    /// This will typically be done in a first time experience, however if the OS resets
    /// the authorization status, like when the app is deleted or the OS updates, this
    /// may be called again.
    private func registerForPushNotifications(completion: ((UNAuthorizationStatus) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: AppController.pushNotificationOptions) {
            allowed, error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
            DispatchQueue.main.async {
                completion?(allowed ? .authorized : .denied)
                guard allowed else { return }
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Deregisters the app from getting push notifications from the PushAPI, as well as
    /// asking the OS to deregister for remote notifications.
    private func deregisterForPushNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
        self.updatePushNotificationToken(nil)
    }

    /// Writes the specified token with the current identity to the
    /// Verse PushAPI.  A nil token value is an implied "disable".
    /// This may also be called in subsequent launches if the OS
    /// has determined the device token has changed, like when the
    /// app is reinstalled or the OS is updated.
    func updatePushNotificationToken(_ token: Data?) {
        // TODO https://app.asana.com/0/914798787098068/1145662769684306/f
        // TODO make sure this gets called when identities are switched or added
        let identities = AppConfigurations.current.compactMap { $0.identity }
        for identity in identities {
            PushAPI.shared.update(token, for: identity) { _, _ in
                
            }
        }
        Analytics.shared.updatePushToken(pushToken: token)
    }

    /// Asks the main view controller to update the notification tab icon.
    /// Note that this does not take into consideration what the actual content
    /// on that view is, this is superceding it for the moment.
    func received(foregroundNotification: RemoteNotificationUserInfo) {
        self.mainViewController?.updateNotificationsTabIcon(hasNotifications: true)
    }

    /// When the local notification is interacted with (tapped), switches to the notifications tab
    /// while the app is moving from the background to the foreground.
    func received(backgroundNotification: UNNotification) {
        self.mainViewController?.selectNotificationsTab(hasNotifications: true)
    }
}

fileprivate extension Data {

    func pushTokenString() -> String {
        return self.map { String(format: "%02.2hhx", $0) }.joined()
    }
}
