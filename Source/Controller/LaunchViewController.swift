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

/// LaunchViewController is used to stand up the app stack at key junctions:
///    - on app launch
///    - after onboarding
///    - after changing AppConfigurations
///
/// It also makes the decision to launch onboarding, or run pre-launch migrations.
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

        let splashImageView = UIImageView(image: UIImage.launch)
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
        
        guard appConfiguration?.bot?.identity == nil else {
            launchIntoMain()
            return
        }
        
        // if simulating then onboard
        if UserDefaults.standard.simulateOnboarding {
            launchIntoOnboarding(simulate: true)
            return
        }

        // if no configuration then onboard
        guard var configuration = appConfiguration else {
            launchIntoOnboarding()
            return
        }

        let identity = configuration.identity
        // if configuration and is required then onboard
        if Onboarding.status(for: identity) == .started {
            launchIntoOnboarding(status: .started)
            return
        }

        // if configuration and not started then already onboarded
        if Onboarding.status(for: identity) == .notStarted {
            Onboarding.set(status: .completed, for: identity)
        }

        // otherwise there is a configuration and onboarding has been completed
        Log.info("Launching with configuration:\n\(configuration)")
        
        Task {
            do {
                // note that hmac key can be nil to switch it off
                guard configuration.network != nil, let bot = configuration.bot else {
                    CrashReporting.shared.reportIfNeeded(
                        error: GoBotError.unexpectedFault("missing configuration needed to start bot")
                    )
                    return
                }
                
                try await bot.login(config: configuration, fromOnboarding: false)
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
        Log.info("Showing main view controller")
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
            title: Localized.error.text,
            message: Localized.Error.login.text,
            preferredStyle: .alert
        )
        let action = UIAlertAction(title: "Restart", style: .default) { _ in
            Task {
                Log.debug("Restarting launch...")
                do {
                    try await bot.logout()
                } catch {
                    // Don't report error here becuase the normal path is to actually receive
                    // a notLoggedIn error
                    Log.optional(error)
                }

                Analytics.shared.forget()
                CrashReporting.shared.forget()
                
                await self.appController.relaunch()
            }
        }
        controller.addAction(action)
        
        let reset = UIAlertAction(title: "Reset", style: .destructive) { _ in
            Task {
                Log.debug("Resetting current configuration and restarting launch...")
                AppConfiguration.current?.unapply()
                do {
                    try await bot.logout()
                } catch {
                    // Don't report error here becuase the normal path is to actually receive
                    // a notLoggedIn error
                    Log.optional(error)
                }

                Analytics.shared.forget()
                CrashReporting.shared.forget()
                
                await self.appController.relaunch()
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
}
