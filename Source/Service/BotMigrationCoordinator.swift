//
//  BotMigrationCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/18/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics
import SwiftUI
import CrashReporting

/// Receives migration callbacks from scuttlego and passes them onto the `BotMigrationController` on the main actor.
class BotMigrationCoordinator: BotMigrationDelegate {
    
    lazy var onRunningCallback: MigrationOnRunningCallback = { _, _ in
        NotificationCenter.default.post(Notification(name: .migrationOnRunning))
    }
    
    lazy var onErrorCallback: MigrationOnErrorCallback = { _, _, errorCode in
        NotificationCenter.default.post(Notification(name: .migrationOnError, userInfo: ["errorCode": errorCode]))
    }
    
    lazy var onDoneCallback: MigrationOnDoneCallback = { _ in
        NotificationCenter.default.post(Notification(name: .migrationOnDone))
    }
    
    private var hostViewController: UIViewController
    
    private lazy var botMigrationController: BotMigrationController = {
        BotMigrationController(hostingController: hostViewController)
    }()
    
    private var hostingController: UIViewController?
    
    init(hostViewController: UIViewController) {
        self.hostViewController = hostViewController
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRunning),
            name: Notification.Name.migrationOnRunning,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onError),
            name: Notification.Name.migrationOnError,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onDone),
            name: Notification.Name.migrationOnDone,
            object: nil
        )
    }
    
    @objc func onRunning(notification: Notification) {
        Task.detached(priority: .high) { @MainActor [hostViewController, botMigrationController] in
            guard self.hostingController == nil else {
                return
            }
            
            Analytics.shared.trackDidStartBotMigration()
            let view = BotMigrationView(viewModel: botMigrationController)
            let hostingController = UIHostingController(rootView: view)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.modalTransitionStyle = .crossDissolve
            hostViewController.present(hostingController, animated: true)
            self.hostingController = hostingController
        }
    }
    
    @objc func onError(notification: Notification) {
        let errorCode = (notification.userInfo?["errorCode"] as? Int64) ?? -1
        Task.detached(priority: .high) { @MainActor [botMigrationController] in
            botMigrationController.showError = true
            Analytics.shared.trackDidFailBotMigration(errorCode: errorCode)
            CrashReporting.shared.reportIfNeeded(error: BotMigrationError(code: errorCode))
        }
    }
    
    @objc func onDone(notification: Notification) {
        Task.detached(priority: .high) { @MainActor [botMigrationController] in
            do {
                try await Bots.current.syncLoggedIdentity()
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            botMigrationController.isDone = true
            Analytics.shared.trackDidFinishBotMigration()
        }
    }
}
///
