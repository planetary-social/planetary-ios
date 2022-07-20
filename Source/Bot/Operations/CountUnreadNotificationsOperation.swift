//
//  CountUnreadNotificationsOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 20/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import Logger
import UIKit

/// Counts the number unread notifications and sets the application badge
class CountUnreadNotificationsOperation: AsynchronousOperation {

    override func main() {
        Log.info("CountUnreadNotificationsOperation started.")
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.numberOfUnreadReports(queue: queue) { [weak self] result in
            switch result {
            case .success(let count):
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = count
                    AppController.shared.mainViewController?.setNotificationsTabBarIcon()
                }
            case .failure(let error):
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            self?.finish()
            Log.info("CountUnreadNotificationsOperation finished.")
        }
    }
}
