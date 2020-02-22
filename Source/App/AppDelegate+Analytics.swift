//
//  AppDelegate+Analytics.swift
//  Planetary
//
//  Created by Christoph on 12/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension MixpanelAnalytics {

    func trackAppStartBackgroundSync() {
        self.time(event: .did,
                  element: .app,
                  name: AnalyticsEnums.Name.backgroundSync.rawValue)
    }

    // Note that this needs to use the same event name as `trackAppStartBackgroundRefresh`
    // otherwise the duration property will not be calculated correctly.
    func trackAppDidBackgroundSync(numberOfMessages: Int,
                                   notificationsOnly: Bool)
    {
        let params = ["number_of_messages": numberOfMessages,
                      "notifications_only": notificationsOnly] as AnalyticsEnums.Params
        self.track(event: .did,
                   element: .app,
                   name: AnalyticsEnums.Name.backgroundSync.rawValue,
                   params: params)
    }

    // TODO trackAppStartNotificationRefresh
    // TODO trackAppDidNotificationRefresh

    func trackTapAppNotification() {
        self.track(event: .tap, element: .app, name: AnalyticsEnums.Name.notification.rawValue)
    }

    func trackAppLaunch() {
        self.track(event: .did, element: .app, name: AnalyticsEnums.Name.launch.rawValue)
    }

    func trackAppForeground() {
        self.track(event: .did, element: .app, name: AnalyticsEnums.Name.foreground.rawValue)
    }

    func trackAppBackground() {
        self.track(event: .did, element: .app, name: AnalyticsEnums.Name.background.rawValue)
    }

    func trackAppExit() {
        self.track(event: .did, element: .app, name: AnalyticsEnums.Name.exit.rawValue)
    }
}
