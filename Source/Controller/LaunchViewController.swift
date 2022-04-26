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

class LaunchViewController: UIViewController {

    // MARK: Lifecycle
    
    var userDefaults = UserDefaults.standard

    convenience init() {
        self.init(nibName: nil, bundle: nil)
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

    private func launch() {

        // if simulating then onboard
        if UserDefaults.standard.simulateOnboarding {
            self.launchIntoOnboarding(simulate: true)
            return
        }

        // if no configuration then onboard
        if AppConfiguration.needsToBeCreated {
            self.launchIntoOnboarding()
            return
        }

        // if configuration and is required then onboard
        if let configuration = AppConfiguration.current,
            let identity = configuration.identity,
            Onboarding.status(for: identity) == .started {
            self.launchIntoOnboarding(status: .started)
            return
        }

        // if configuration and not started then already onboarded
        if let configuration = AppConfiguration.current,
            let identity = configuration.identity,
            Onboarding.status(for: identity) == .notStarted {
            Onboarding.set(status: .completed, for: identity)
        }

        // otherwise there is a configuration and onboarding has been completed

        // TODO analytics
        // this should no longer be necessary with onboarding
        guard let configuration = AppConfiguration.current, configuration.canLaunch else {
            self.alert(message: "The configuration is incomplete and cannot be launched. Please try deleting and reinstalling the app.")
            return
        }

        // TODO this should be an analytics track()
        // TODO include app installation UUID
        // Analytics.shared.app(launch)
        Log.info("Launching with configuration '\(configuration.name)'")
        
        Task {
            await self.migrateIfNeeded(using: configuration)
            
            // note that hmac key can be nil to switch it off
            guard configuration.network != nil else { return }
            guard configuration.secret != nil else { return }
            guard let bot = configuration.bot else { return }
            
            do {
                try await bot.login(config: configuration)
            } catch {
                self.handleLoginFailure(with: error, configuration: configuration)
            }
            
            self.launchIntoMain()
            await self.trackLogin(with: configuration)
        }
    }
    
    // MARK: - Helpers

    private func launchIntoOnboarding(status: Onboarding.Status = .notStarted,
                                      simulate: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AppController.shared.showOnboardingViewController(status, simulate)
        }
    }

    @MainActor private func launchIntoMain() {
        // no need to start a sync here, we can do it later
        // also, user is already logged in

        // transition to main app UI
        AppController.shared.showMainViewController(animated: true)
    }

    private func handleLoginFailure(with error: Error, configuration: AppConfiguration) {
        guard let network = configuration.network else { return }
        guard let bot = configuration.bot else { return }
        guard let secret = configuration.secret else { return }
        
        Log.optional(error)
        CrashReporting.shared.reportIfNeeded(
            error: error,
            metadata: [
                "action": "login-from-launch",
                "network": network,
                "identity": secret.identity
            ]
        )
        
        let controller = UIAlertController(title: Text.error.text,
                                           message: Text.Error.login.text,
                                           preferredStyle: .alert)
        let action = UIAlertAction(title: "Restart", style: .default) { _ in
            Log.debug("Restarting launch...")
            bot.logout { err in
                // Don't report error here becuase the normal path is to actually receive
                // a notLoggedIn error
                Log.optional(err)
                
                ssbDropIndexData()
                
                Analytics.shared.forget()
                CrashReporting.shared.forget()
                
                Task {
                    await AppController.shared.relaunch()
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
                    await AppController.shared.relaunch()
                }
            }
        }
        controller.addAction(reset)
        
        AppController.shared.showAlertController(with: controller, animated: true)
    }
    
    private func trackLogin(with configuration: AppConfiguration) async {
        guard let network = configuration.network else { return }
        guard let bot = configuration.bot else { return }
        
        do {
            guard let identity = configuration.secret?.identity else {
                Log.error("Could not fetch identity while logging in.")
                return
            }
            
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
    
    private func migrateIfNeeded(using configuration: AppConfiguration) async {
        
        do {
            try await Beta1MigrationCoordinator.performBeta1MigrationIfNeeded(
                appConfiguration: configuration,
                appController: AppController.shared,
                userDefaults: userDefaults
            )
        } catch {
            // TODO: handle
            Log.optional(error)
        }
    }
}
