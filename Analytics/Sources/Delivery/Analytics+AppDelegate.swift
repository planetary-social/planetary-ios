//
//  Analytics+AppDelegate.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation

public extension Analytics {

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

    func trackDidScheduleBackgroundTask(taskIdentifier: String, for date: Date?) {
        var params: [String: Any] = ["task_identifier": taskIdentifier]
        if let date = date {
            params["earliest_begin_date"] = date
        }
        service.track(event: .did, element: .app, name: "backgroundTaskSchedule", params: params)
    }
    
    func trackDidCancelBackgroundSync() {
        service.track(event: .did, element: .app, name: "backgroundTaskCancel")
    }
    
    func trackDidCompleteBackgroundSync(success: Bool, newMessageCount: Int) {
        let params: [String: Any] = [
            "success": success,
            "new_message_count": newMessageCount
        ]
        service.track(event: .did, element: .app, name: "backgroundSyncComplete", params: params)
    }

    func trackDidStartBackgroundTask(taskIdentifier: String) {
        let params = ["task_identifier": taskIdentifier]
        service.track(event: .did, element: .app, name: "backgroundTaskStart", params: params)
    }
    
    func trackBotDeadlock() {
        service.track(event: .did, element: .bot, name: "deadlock")
    }

    func trackDidReceiveRemoteNotification() {
        service.track(event: .did, element: .app, name: "receive_remote_notification")
    }
}
