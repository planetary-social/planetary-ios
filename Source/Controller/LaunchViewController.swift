//
//  LaunchViewController.swift
//  FBTT
//
//  Created by Christoph on 3/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

// Mark UserDefaults as @Sendable for now, because docs say it's thread safe and I can't find another good alternative.
#if compiler(>=5.5) && canImport(_Concurrency)
extension UserDefaults: @unchecked Sendable {}
#endif

class LaunchViewController: UIViewController {

    // MARK: Lifecycle
    
    var appConfiguration: AppConfiguration?
    var appController: AppController
    var userDefaults: UserDefaults
    
    init(
        appConfiguration: AppConfiguration?,
        appController: AppController,
        userDefaults: UserDefaults = UserDefaults.standard
    ) {
        self.appConfiguration = appConfiguration
        self.appController = appController
        self.userDefaults = userDefaults
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {

        super.viewDidLoad()
        self.view.backgroundColor = UIColor.splashBackground

        let splashImageView = UIImageView(image: UIImage(named: "launch"))
        splashImageView.contentMode = .scaleAspectFit
        Layout.center(splashImageView, in: self.view, size: CGSize(width: 188, height: 248))
        
        self.launch()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Launch")
        Analytics.shared.trackDidShowScreen(screenName: "launch")
    }

    // MARK: Actions

    @MainActor
    private func launch() {

        // if simulating then onboard
        if UserDefaults.standard.simulateOnboarding {
            self.launchIntoOnboarding(simulate: true)
            return
        }

        // if no configuration then onboard
        guard var configuration = appConfiguration else {
            self.launchIntoOnboarding()
            return
        }

        let identity = configuration.identity
        // if configuration and is required then onboard
        if Onboarding.status(for: identity) == .started {
            self.launchIntoOnboarding(status: .started)
            return
        }

        // if configuration and not started then already onboarded
        if Onboarding.status(for: identity) == .notStarted {
            Onboarding.set(status: .completed, for: identity)
        }

        // otherwise there is a configuration and onboarding has been completed

        // TODO analytics
        // this should no longer be necessary with onboarding
        guard configuration.canLaunch else {
            self.alert(message: "The configuration is incomplete and cannot be launched. Please try deleting and reinstalling the app.")
            return
        }

        // TODO this should be an analytics track()
        // TODO include app installation UUID
        // Analytics.shared.app(launch)
        Log.info("Launching with configuration '\(configuration.name)'")
        
        Task {
            login: do {
                let isMigrating = try await self.migrateIfNeeded(using: configuration)
                if isMigrating {
                    break login
                }
                
                if let newConfiguration = try await self.fix814AccountsIfNecessary(using: configuration) {
                    configuration = newConfiguration
                    break login
                }
                
                // note that hmac key can be nil to switch it off
                guard configuration.network != nil else { return }
                guard let bot = configuration.bot else { return }
                
                try await bot.login(config: configuration)
            } catch {
                self.handleLoginFailure(with: error, configuration: configuration)
            }
            
            self.launchIntoMain()
            await self.trackLogin(with: configuration)
        }
    }
    
    // MARK: - Helpers

    private func launchIntoOnboarding(
        status: Onboarding.Status = .notStarted,
        simulate: Bool = false
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.appController.showOnboardingViewController(status, simulate)
        }
    }

    @MainActor private func launchIntoMain() {
        // no need to start a sync here, we can do it later
        // also, user is already logged in

        // transition to main app UI
        appController.showMainViewController(animated: true)
    }

    func handleLoginFailure(with error: Error, configuration: AppConfiguration) {
        Log.error("Bot.login failed")
        Log.optional(error)
        CrashReporting.shared.reportIfNeeded(
            error: error,
            metadata: [
                "action": "login-from-launch",
                "network": configuration.network?.string ?? "",
                "identity": configuration.secret.identity
            ]
        )
        
        guard let bot = configuration.bot else { return }
        
        let controller = UIAlertController(
            title: Text.error.text,
            message: Text.Error.login.text,
            preferredStyle: .alert
        )
        let action = UIAlertAction(title: "Restart", style: .default) { _ in
            Log.debug("Restarting launch...")
            bot.logout { error in
                // Don't report error here becuase the normal path is to actually receive
                // a notLoggedIn error
                Log.optional(error)
                
                ssbDropIndexData()
                
                Analytics.shared.forget()
                CrashReporting.shared.forget()
                
                Task {
                    await self.appController.relaunch()
                }
            }
        }
        controller.addAction(action)
        
        let reset = UIAlertAction(title: "Reset", style: .destructive) { _ in
            Log.debug("Resetting current configuration and restarting launch...")
            AppConfiguration.current?.unapply()
            bot.logout { error in
                // Don't report error here becuase the normal path is to actually receive
                // a notLoggedIn error
                Log.optional(error)
                
                ssbDropIndexData()
                
                Analytics.shared.forget()
                CrashReporting.shared.forget()
                
                Task {
                    await self.appController.relaunch()
                }
            }
        }
        controller.addAction(reset)
        
        appController.showAlertController(with: controller, animated: true)
    }
    
    private func trackLogin(with configuration: AppConfiguration) async {
        guard let network = configuration.network else { return }
        guard let bot = configuration.bot else { return }
        
        do {
            let identity = configuration.secret.identity
            
            let about = try await bot.about()
            CrashReporting.shared.identify(
                identifier: identity,
                name: about?.name,
                networkKey: network.string,
                networkName: network.name
            )
            Analytics.shared.identify(
                identifier: identity,
                name: about?.name,
                network: network.name
            )
        } catch {
            Log.optional(error)
            // No need to show an alert to the user as we can fetch the current about later
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }
    
    private func migrateIfNeeded(using configuration: AppConfiguration) async throws -> Bool {
        try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
            appConfiguration: configuration,
            appController: appController,
            userDefaults: userDefaults
        )
    }
    
    private func fix814AccountsIfNecessary(using configuration: AppConfiguration) async throws -> AppConfiguration? {
        try await Fix814AccountsHelper.fix814Account(
            configuration,
            appController: appController,
            userDefaults: userDefaults
        )
    }
}


