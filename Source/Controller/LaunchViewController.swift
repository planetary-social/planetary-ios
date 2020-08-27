//
//  LaunchViewController.swift
//  FBTT
//
//  Created by Christoph on 3/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class LaunchViewController: UIViewController {

    // MARK: Lifecycle

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {

        super.viewDidLoad()
        self.view.backgroundColor = UIColor.background.default

        let splashImageView = UIImageView(image: UIImage(named: "splash"))
        splashImageView.contentMode = .scaleAspectFit
        Layout.center(splashImageView, in: self.view, size: CGSize(width: 181, height: 231))
        
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
            Onboarding.status(for: identity) == .started
        {
            self.launchIntoOnboarding(status: .started)
            return
        }

        // if configuration and not started then already onboarded
        if let configuration = AppConfiguration.current,
            let identity = configuration.identity,
            Onboarding.status(for: identity) == .notStarted
        {
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

        // note that hmac key can be nil to switch it off
        guard let network = configuration.network else { return }
        guard let secret = configuration.secret else { return }
        guard let bot = configuration.bot else { return }
        
        bot.login(network: network, hmacKey: configuration.hmacKey, secret: secret) { error in
            
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error,
                                                 metadata: ["action": "login-from-launch",
                                                            "network": network,
                                                            "identity": secret.identity])
            
            guard error == nil else {
                let controller = UIAlertController(title: Text.error.text,
                                                   message: Text.Error.login.text,
                                                   preferredStyle: .alert)
                
                var action = UIAlertAction(title: "Restart", style: .default) { _ in
                    controller.dismiss(animated: true, completion: nil)
                    bot.logout() {
                        err in
                        Log.optional(err)
                        ssbDropIndexData()
                        AppController.shared.relaunch() // this should call self.login() again right?!
                    }
                }
                controller.addAction(action)

                action = UIAlertAction(title: "Ignore", style: .cancel) { _ in
                    controller.dismiss(animated: true, completion: nil)
                    DispatchQueue.main.async {
                        AppController.shared.showMainViewController(animated: true)
                    }
                }
                controller.addAction(action)
                AppController.shared.showAlertController(with: controller, animated: true)
                return
            }
            
            self.launchIntoMain()
            
            bot.about { (about, aboutErr) in
                Log.optional(aboutErr)
                // No need to show an alert to the user as we can fetch the current about later
                CrashReporting.shared.reportIfNeeded(error: aboutErr)
                CrashReporting.shared.identify(about: about, network: network)
                Analytics.shared.identify(about: about, network: network)
            }
        }
    }

    private func launchIntoOnboarding(status: Onboarding.Status = .notStarted,
                                      simulate: Bool = false)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AppController.shared.showOnboardingViewController(status, simulate)
        }
    }

    private func launchIntoMain() {


        // no need to start a sync here, we can do it later
        // also, user is already logged in

        // transition to main app UI
        DispatchQueue.main.async {
            AppController.shared.showMainViewController(animated: true)
        }
    }
}
