//
//  BotMigrationController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/18/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import SwiftUI
import UIKit

/// A controller that provides data to the `BotMigrationView`.
class BotMigrationController: BotMigrationViewModel {
    
    /// Indicates that the migration has encountered an error.
    @Published var showError = false
    
    /// Indicates that the migration has completed.
    @Published var isDone = false
    
    /// A reference to the controller hosting the SwiftUI view. Used for dismissal.
    private var hostingController: UIViewController
    
    init(hostingController: UIViewController) {
        self.hostingController = hostingController
    }
    
    func dismissPressed() {
        let userDefaults = UserDefaults.standard
        let didMigrateIdentityToScuttlego = userDefaults.bool(forKey: UserDefaults.didMigrateIdentityToScuttlego)
        if didMigrateIdentityToScuttlego {
            hostingController.dismiss(animated: true)
        } else {
            Task.detached(priority: .high) { [hostingController] in
                do {
                    if AppConfiguration.current?.numberOfPublishedMessages ?? 0 > 10 {
                        // Only sync for users that previously published many messages with go-ssb
                        // and could have forked their feed
                        try await Bots.current.syncLoggedIdentity()
                    }
                    userDefaults.setValue(true, forKey: UserDefaults.didMigrateIdentityToScuttlego)
                } catch {
                    CrashReporting.shared.reportIfNeeded(error: error)
                }
                Task.detached { @MainActor [hostingController] in
                    hostingController.dismiss(animated: true)
                }
            }
        }
    }
    
    func tryAgainPressed() {
        Task {
            await AppController.shared.relaunch()
        }
    }
}
