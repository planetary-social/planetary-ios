//
//  ClearUnreadNotificationsOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 19/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import Logger
import UIKit

/// Clears all unread notifications and resets the application badge
class ClearUnreadNotificationsOperation: AsynchronousOperation {

    override func main() {
        Log.info("ClearUnreadNotificationsOperation started.")
        Bots.current.markAllMessageAsRead(queue: dispatchQueue) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    AppController.shared.mainViewController?.setNotificationsTabBarIcon()
                }
            case .failure(let error):
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            self?.finish()
            Log.info("ClearUnreadNotificationsOperation finished.")
        }
    }
}
