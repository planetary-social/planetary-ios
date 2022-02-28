//
//  Analytics+AppDelegate.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation

public extension Analytics {

    // TODO trackAppStartNotificationRefresh
    // TODO trackAppDidNotificationRefresh

    func trackTapAppNotification() {
        service.track(event: .tap, element: .app, name: "notification")
    }

    func trackAppLaunch() {
        service.track(event: .did, element: .app, name: "launch")
    }

    func trackAppForeground() {
        service.track(event: .did, element: .app, name: "foreground")
    }

    func trackAppBackground() {
        service.track(event: .did, element: .app, name: "background")
    }

    func trackAppExit() {
        service.track(event: .did, element: .app, name: "exit")
    }

    func trackDidBackgroundFetch() {
        service.track(event: .did, element: .app, name: "backgroundFetch")
    }

    func trackDidBackgroundTask(taskIdentifier: String) {
        let params = ["task_identifier": taskIdentifier]
        service.track(event: .did, element: .app, name: "backgroundTask", params: params)
    }

    func trackDidReceiveRemoteNotification() {
        service.track(event: .did, element: .app, name: "receive_remote_notification")
    }

}
